require 'rubygems'
require 'highline'
require 'git'
require 'active_support/time'
require 'teambox-client'
require 'pp'

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
        puts "#{i+1})\t[#{t.data["id"]}] #{t.data["name"]} - #{status(t.data['status'])}"
      end
    end

    def run
      tasks = []
      current_user = client.current_user.data
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
        if mensaje_adicional.blank?
          commit_msg = "[#{selected_task.data['id']}] #{selected_task.data['name']}"
        else
          commit_msg = "[#{selected_task.data['id']}] #{mensaje_adicional}"
        end
        system "git commit -m '#{commit_msg}'"
        break
      end
    end
  end
end