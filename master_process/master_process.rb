#coding=utf-8
root = File.dirname(__FILE__)
$:.unshift(root) unless $:.include?(root)


require "json"
require "eventmachine"
require "em-http-request"

require "threads_manager"
require "settings"



module MasterProcess

#This server gets commands to its PORT:
#  /^CREATE PROCESS WITH (\d+) WORKERS$/ - create a process with N workers
#  /^TERMINATE PROCESS (\d+)$/ - terminate the process safe
#  /^KILL PROCESS (\d+)$/ - kill the process
#  /^UPDATE (\d+)#(\d+) STATE (-?\d+)$/ - refresh the state for thread X of process Y
#
#After getting any command it updates state of threads and sends the information to NOTIFY_URL by HTTP

module ProcessManagerServer
    include EventMachine::Protocols::LineText2

    def initialize(pids, *args)
      @pids = pids
      super *args
    end

    #Process the command
    def receive_line(command)
      MasterProcess.logger.debug "GOT COMMAND: #{command}"

      begin

        case command
          when /\ACREATE PROCESS WITH (\d+) WORKERS\z/
            create_process(Regexp::last_match.captures[0].to_i)
          when /\ATERMINATE PROCESS (\d+)\z/
            terminate(Regexp::last_match.captures[0].to_i)
          when /\AKILL PROCESS (\d+)\z/
            kill(Regexp::last_match.captures[0].to_i)
          when /\AUPDATE (\d+)#(\d+) STATE (-?\d+)\z/
            pid, thread, state = Regexp::last_match.captures.collect { |c| c.to_i }
            update(pid, thread, state)
          else
            MasterProcess.logger.error "INVALID COMMAND #{command.inspect}"
        end

      rescue Exception => e
        MasterProcess.logger.error "#{e.message}\n#{e.backtrace.inspect}"
        send_data "ERROR: #{e.message} #{e.backtrace.inspect}\n"
      else
        send_data "OK\n"
        notify_clients
      end

      close_connection_after_writing
    end

    #Create a new process
    def create_process(workers_count)
      pid = start_threads(workers_count)
      @pids[pid] = {}
    end

    #Terminate the process safe, killing all threads one by one. Send SIGTERM to the process.
    def terminate(pid)
      process_kill(15, pid)
    end

    #Kill the process. Send SIGKILL.
    def kill(pid)
      process_kill(9, pid) #SIGKILL
      @pids.delete(pid)

    end

    #Update the state of threads.
    def update(pid, thread, state)
      @pids[pid] ||= {}

      if state.to_i > 0
        @pids[pid][thread] = state
      else
        @pids[pid].delete(thread)
        @pids.delete pid if @pids[pid].empty?
      end
    end

    #Notify web server about state changes via HTTP.
    def notify_clients
      http_post body: {data: @pids.to_json}
    end

    def pids
      @pids
    end

    private

    def start_threads(workers_count)
      ThreadsManager.start workers_count
    end

    def process_kill(sig, pid)
      Process.kill sig, pid
    end

    def http_post(opts)
      http = EventMachine::HttpRequest.new(NOTIFY_URL).post opts
      http.errback { MasterProcess.logger.error "Cannot post data to #{NOTIFY_URL}" }
      http
    end
  end

  def self.main
    EventMachine::run do

      puts "Start process manager server on #{HOST}:#{PORT}"
      MasterProcess.logger.info "Start process manager server on #{HOST}:#{PORT}"
      pids = {}
      EM::start_server HOST, PORT, ProcessManagerServer, pids

      trap "TERM" do
        ThreadsManager.kill_safe
      end
    end
  end

end
if __FILE__ == $0
  MasterProcess.main
end
