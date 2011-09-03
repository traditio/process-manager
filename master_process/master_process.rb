# coding: UTF-8
$LOAD_PATH << File.expand_path(File.dirname(__FILE__))

require 'rubygems'
require 'logger'
require 'json'

require 'eventmachine'
require "em-http-request"

require "worker"



$log = Logger.new($stdout)


NOTIFY_URL = 'http://localhost:3000/update/'
HOST = '127.0.0.1'
PORT = 7001


module ProcessManagerServer
  include EventMachine::Protocols::LineText2

  def initialize(pids)
    @pids = pids
  end

  def receive_line(command)
    $log.debug "GOT COMMAND: #{command}"
    begin
      case command
        when /^CREATE PROCESS WITH (\d+) WORKERS$/
          create_process(Regexp::last_match.captures[0].to_i)
        when /^TERMINATE PROCESS (\d+)$/
          terminate(Regexp::last_match.captures[0].to_i)
        when /^KILL PROCESS (\d+)$/
          kill(Regexp::last_match.captures[0].to_i)
        when /^UPDATE (\d+)#(\d+) STATE (-?\d+)$/
          pid, thread, state = Regexp::last_match.captures.collect { |c| c.to_i }
          update(pid, thread, state)
        else
          $log.error "INVALID COMMAND"
      end
    rescue
      send_data("ERROR: #{e.message} #{e.backtrace.inspect}\n")
      close_connection_after_writing
      return
    end
    send_data("OK\n")
    close_connection_after_writing
    notify_clients
  end

  def create_process(workers_count)
    pid = ThreadsManager.start(workers_count)
    @pids[pid] = {} unless pid.nil?
  end

  def terminate(pid)
    return unless @pids.member?(pid)
    begin
      Process.kill(15, pid)
    rescue Exception => e
      $log.debug "#{e.message}\n#{e.backtrace.inspect}"
    end
  end

  def kill(pid)
    return unless @pids.member?(pid)
    begin
      Process.kill(9, pid)
    rescue Exception => e
      $log.debug "#{e.message}\n#{e.backtrace.inspect}"
      return
    end
    @pids.delete(pid)
  end

  def update(pid, thread, state)
    @pids[pid] ||= {}
    if state > 0
      @pids[pid][thread] = state
    else
      @pids[pid].delete(thread)
      @pids.delete(pid) if @pids[pid].empty?
    end
  end

  def notify_clients

    http = EventMachine::HttpRequest.new(NOTIFY_URL).post :body => {:data => @pids.to_json}

    http.errback { $log.error(http.response) }
  end

end


EventMachine::run do
  puts "Start process manager server on #{HOST}:#{PORT}"
  pids = {}
  EM::start_server HOST, PORT, ProcessManagerServer, pids
end