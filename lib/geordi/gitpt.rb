require 'rubygems'
require 'highline'
require 'pivotal-tracker'
require 'yaml'
require 'git'
require 'active_support/time'

module Geordi
  class Gitpt

    attr_reader :token, :initials, :settings_file, :deprecated_token_file,
                :highline, :applicable_stories, :memberships

    def initialize
      @highline = HighLine.new
      @settings_file = File.join(ENV['HOME'], '.gitpt')
      @deprecated_token_file = File.join(ENV['HOME'], '.pt_token')
      load_settings
      settings_were_invalid = (not settings_valid?)

      hello unless settings_valid?
      request_settings while not settings_valid?
      stored if settings_were_invalid

      PivotalTracker::Client.use_ssl = true
      PivotalTracker::Client.token = token
    end

    def settings_valid?
      token and token.size > 10
    end

    def bold(string)
      HighLine::BOLD + string + HighLine::RESET
    end

    def highlight(string)
      bold HighLine::BLUE + string
    end

    def hello
      highline.say HighLine::RESET
      highline.say "Welcome to #{bold 'gitpt'}.\n\n"
    end

    def left(string)
      leading_whitespace = (string.match(/\A( +)[^ ]+/) || [])[1]
      string.gsub! /^#{leading_whitespace}/, '' if leading_whitespace
      string
    end

    def loading(message, &block)
      print message
      STDOUT.flush
      yield
      print "\r" + ' ' * message.size + "\r" # Remove loading message
      STDOUT.flush
    end

    def stored
      highline.say left(<<-MESSAGE)
        Thank you. Your settings have been stored at #{highlight @settings_file}
        You may remove that file for the wizard to reappear.

        ----------------------------------------------------

      MESSAGE
    end

    def request_settings
      highline.say highlight('Your settings are missing or invalid.')
      highline.say "Please configure your Pivotal Tracker access.\n\n"
      token = highline.ask bold("Your API key:") + " "
      initials = highline.ask bold("Your PT initials") + " (optional, used for highlighting your stories): "
      highline.say "\n"

      settings = { :token => token, :initials => initials }
      File.open settings_file, 'w' do |file|
        file.write settings.to_yaml
      end
      load_settings
    end

    def load_settings
      if File.exists? settings_file
        settings = YAML.load(File.read settings_file)
        @initials = settings[:initials]
        @token = settings[:token]
      else
        if File.exists?(deprecated_token_file)
          highline.say left(<<-MESSAGE)
            #{HighLine::YELLOW}You are still using #{highlight(deprecated_token_file) + HighLine::YELLOW} which will be deprecated in a future version.
            Please migrate your settings to ~/.gitpt or remove #{deprecated_token_file} for the wizard to cast magic.
          MESSAGE
          @token = File.read(deprecated_token_file)
        end
      end
    end

    def load_projects
      project_id_filename = '.pt_project_id'
      if File.exists?(project_id_filename)
        project_ids = File.read('.pt_project_id').split(/[\s]+/).map(&:to_i)
      end

      unless project_ids and project_ids.size > 0
        highline.say left(<<-MESSAGE)
          Sorry, I could not find a project ID in #{highlight project_id_filename} :(

          Please put at least one Pivotal Tracker project id into #{project_id_filename} in this directory.
          You may add multiple IDs, separated using white space.
        MESSAGE
        exit 1
      end

      loading 'Connecting to Pivotal Tracker...' do
        projects = project_ids.collect do |project_id|
          PivotalTracker::Project.find(project_id)
        end

        @memberships = projects.collect(&:memberships).map(&:all).flatten

        @applicable_stories = projects.collect do |project|
          project.stories.all(:state => 'started,finished,rejected')
        end.flatten
      end
    end

    def choose_story
      selected_story = nil

      highline.choose do |menu|
        menu.header = "Choose a story"
        applicable_stories.each do |story|
          owner_name = story.owned_by
          owner = if owner_name
            owners = memberships.select{|member| member.name == owner_name}
            owners.first ? owners.first.initials : '?'
          else
            '?'
          end

          state = story.current_state
          if state == 'started'
            state = HighLine::GREEN + state + HighLine::RESET
          elsif state != 'finished'
            state = HighLine::RED + state + HighLine::RESET
          end
          state += HighLine::BOLD if owner == initials

          label = "(#{owner}, #{state}) #{story.name}"
          label = bold(label) if owner == initials
          menu.choice(label) { selected_story = story }
        end
        menu.hidden ''
      end

      if selected_story
        message = highline.ask("\nAdd an optional message")
        highline.say message

        commit_message = "[##{selected_story.id}] #{selected_story.name}"
        if message.strip != ''
          commit_message << ' - '<< message.strip
        end
        pwd = `pwd`.strip
        git = Git.open(pwd)
        git.commit(commit_message)
        commit_sha = git.object('HEAD').sha
        message_note = <<-EOF
          #{message.strip}
          Commit SHA on '#{current_branch}': #{commit_sha}

          Repositorio: #{url_repo(git)}
        EOF
        note_at_date = Time.now.in_time_zone("EST").strftime("%m/%d/%Y 05:00 %Z")
        selected_story.notes.create(:text => message_note, :noted_at => note_at_date)
      end
    end

    def url_repo(git)
      remote_origin_url = git.config['remote.origin.url']
      commit_sha = git.object('HEAD').sha
      if bitbucket?(remote_origin_url)
        match_username = /bitbucket.org\/([a-zA-Z0-9]+)\/|bitbucket.org:([a-zA-Z0-9]+)\//.match(remote_origin_url)
        username = match_username[1] || match_username[2]
        url_repo = "https://bitbucket.org/#{username}/#{project_name(git)}/changeset/#{commit_sha}"
      elsif github?(remote_origin_url)
        match_username = /github.com\/([a-zA-Z0-9]+)\/|github.com:([a-zA-Z0-9]+)\//.match(remote_origin_url)
        username = match_username[1] || match_username[2]
        url_repo = "https://github.com/#{username}/#{project_name(git)}/commit/#{commit_sha}"
      elsif repositoryhosting?(remote_origin_url)
        match_username = /https:\/\/([a-zA-Z0-9]+)\.repositoryhosting\.com|ssh:\/\/git@([a-zA-Z0-9]+)\./.match(remote_origin_url)
        username = match_username[1] || match_username[2]
        url_repo = "https://#{username}.repositoryhosting.com/trac/#{username}_#{project_name(git)}/changeset/#{commit_sha}"
      end
      url_repo
    end

    def project_name(git)
      return @project_name unless @project_name.nil?
      remote_origin_url = git.config['remote.origin.url']
      m = /\/([a-zA-Z0-9]+)\.git$/.match(remote_origin_url)
      @project_name = m[1]
    end

    def current_branch
      b = `git branch`.split("\n").delete_if { |i| i[0] != "*" }
      b.first.gsub("* ","")
    end

    def bitbucket?(repo)
      return false if repo.nil?
      repo.include?('bitbucket')
    end

    def github?(repo)
      return false if repo.nil?
      repo.include?('github')
    end

    def repositoryhosting?(repo)
      return false if repo.nil?
      repo.include?('repositoryhosting')
    end


    def run
      load_projects
      choose_story
    end

  end
end
