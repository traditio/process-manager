# coding: UTF-8
require 'rubygems'
require 'logger'
require 'json'

require 'eventmachine'
require "em-http-request"

require_relative "worker"

$log = Logger.new(File.expand_path("../../logs/development.log"))


NOTIFY_URL = 'http://localhost:3000/update/'
HOST = '127.0.0.1'
PORT = 7001


module ProcessManagerServer
  include EventMachine::Protocols::LineText2

  attr_reader :pids

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
    rescue Exception => e
      send_data("ERROR: #{e.message} #{e.backtrace.inspect}\n")
      close_connection_after_writing
      return
    end
    send_data("OK\n")
    close_connection_after_writing
    notify_clients
  end

  def create_process(workers_count)
    pid = start_threads(workers_count)
    @pids[pid] = {} unless pid.nil?
  end

  def terminate(pid)
    raise ArgumentError("No proccess with PID #{pid}") unless @pids.member?(pid)
    begin
      process_kill(15, pid)
    rescue Exception => e
      $log.debug "#{e.message}\n#{e.backtrace.inspect}"
    end
  end

  def kill(pid)
    raise ArgumentError("No proccess with PID #{pid}") unless @pids.member?(pid)
    begin
      process_kill(9, pid)
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

    http_post :body => {:data => @pids.to_json}

  end

  private

  def start_threads(workers_count)
    ThreadsManager.start(workers_count)
  end

  def process_kill(sig, pid)
    Process.kill(sig, pid)
  end

  def http_post(opts)
    http = EventMachine::HttpRequest.new(NOTIFY_URL).post opts
    http.errback { $log.error(http.response) }
    http
  end


end

if __FILE__ == $0
  EventMachine::run do
    puts "Start process manager server on #{HOST}:#{PORT}"
    pids = {}
    EM::start_server HOST, PORT, ProcessManagerServer, pids
  end
end
