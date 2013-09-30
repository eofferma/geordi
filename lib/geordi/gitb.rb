require 'rubygems'
require 'highline'
require 'git'
require 'active_support/time'
require 'pp'

require "httparty"
require "json"
require "oauth2"
require "uri"

directory = File.expand_path(File.dirname(__FILE__))
%w(teambox_oauth reference_list teambox result_set).each { |lib| require File.join(directory, '../teambox-client', lib) }

module Geordi
  class Gitb
   attr_reader :username, :password, :client

    def initialize(username, password)
      @username = username
      @password = password
      @client = Teambox::Client.new(:base_uri => 'https://teambox.com/api/1', :auth => {:user => @username, :password => @password})
    end

    def status(n_status)
      case n_status
        when 0
          return "nuevo"
        when 1
          return "sin_asignar"
        when 2
          return "en_espera"
        when 3
          return "resuelto"
        when 4
          return "rechazado"
      end

    end

    def print_tasks(tasks)
      tasks.each_with_index do |t, i|
        puts "#{i+1})\t[#{t.data["id"]}] #{to_utf8(t.data["name"])} - #{status(t.data['status'])}"
      end
    end

    def to_utf8(str)
      str = str.force_encoding("UTF-8")
      return str if str.valid_encoding?
      str = str.force_encoding("BINARY")
      str.encode("UTF-8", invalid: :replace, undef: :replace)
    end

    def run
      tasks = []
      project = client.project('clubventa')
      project_id = project.data["id"]
      project.tasks("status[]=0&status[]=1&status[]=2&count=0").each do |t|
        tasks << t unless t.data["assigned_id"].nil?
      end
      tasks.sort! do |t1, t2|
        t1.data['position'] <=> t2.data['position']
      end

      while true
        print_tasks tasks
        print "\nFavor ingresa el numero de la tarea que quieres commitear: "
        numero_tarea = gets.chomp.to_i
        next if numero_tarea > tasks.length
        selected_task = tasks[numero_tarea - 1]
        print "\n\nIngresa comentario adicional:\n\n"
        mensaje_adicional = gets.chomp.strip
        commit_msg = "DEFAULT MESSAGE COMMIT"
        if mensaje_adicional.blank?
          commit_msg = "#{to_utf8(selected_task.data['name'])} [#{selected_task.data['id']}]"
        else
          commit_msg = "#{mensaje_adicional} [#{selected_task.data['id']}]"
        end
        pwd = `pwd`.strip
        git = Git.open(pwd)
        git.commit(commit_msg)
        break
      end
    end
  end
end