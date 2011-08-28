# coding: UTF-8
require 'rubygems'
require 'eventmachine'
require 'logger'
require 'eventmachine'
require "./worker.rb"

$log = Logger.new($stdout)


module ProcessManagerServer
  include EventMachine::Protocols::LineText2

  def initialize pids
    @pids = pids
  end
  def post_init
    $log.info 'post init'

  end

  def connection_completed
    $log.info 'super'

  end
  def receive_line(line)

    $log.debug line
    if line.match(/^CREATE PROCESS WITH (\d+) WORKERS$/)
      workers_count = Regexp::last_match.captures[0].to_i
      @pids << start_threads(workers_count)
    elsif line.match(/^TERMINATE PROCESS (\d+)$/)
      pid = Regexp::last_match.captures[0].to_i
      if @pids.include? pid
        Process.kill(15, pid)
      end
    elsif line.match(/^KILL PROCESS (\d+)$/)
      pid = Regexp::last_match.captures[0].to_i
      if @pids.include? pid
        Process.kill(9, pid)
      end
    else
      $log.error "Received invalid command: #{line.inspect}"
    end
  end
  def receive_data d
    $log.debug "receive data: #{d}"
    super
  end

  def unbind
    $log.debug "unbind #{error?}"

  end
end


EventMachine::run do
  pids = []
  puts "Start master process server on 127.0.0.1:7001"
  EM::start_server '127.0.0.1', 7001, ProcessManagerServer, pids
end