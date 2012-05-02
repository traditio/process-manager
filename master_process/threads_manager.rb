#coding=utf-8
root = File.dirname(__FILE__)
$:.unshift(root) unless $:.include?(root)

require "observer"
require "socket"
require "timeout"

require "settings"


#Threads state observer.
#When a thread changes its state it sends a new state to the Process manager through the socket.
#If the connection is unavailable, it logs an error.
module MasterProcess
  class ThreadStateObserver

    def initialize(thread)
      @thread = thread
      @thread.add_observer(self)
    end

    def update(state)
      begin
        timeout(SOCKET_TIMEOUT) do
          conn = create_connection
          puts "created conn #{conn.inspect}"
          conn.puts "UPDATE #{@thread.thread_id} STATE #{state}"
          conn.close
        end
      rescue Timeout::Error
        MasterProcess.logger.error "Can't send thread #{@thread.thread_id} state to #{PROCESS_MANAGER_HOST}:#{PROCESS_MANAGER_PORT}, timeout exceed"
      end
    end

    private

    def create_connection
      TCPSocket.open(PROCESS_MANAGER_HOST, PROCESS_MANAGER_PORT)
    end
  end


  #The thread which can kill itself safe.
  #The thread changes its state in the cycle in particular time periods. It notifies the Process Manager about state changing.
  class SafeKilledThread < Thread
    include Observable
    attr_reader :thread_id, :state

    def initialize
      @thread_id = "#{$$}##{object_id}"
      MasterProcess.logger.debug "Start new thread #{@thread_id}"
      @states = (1..5).cycle
      @state = 0 # if @state < 0 it means that the thread is involved in the killing process

      super do
        loop do
          change_state
          sleep rand(CHANGE_STATE_EVERY_SEC_MIN..CHANGE_STATE_EVERY_SEC_MAX)
        end
      end
    end

    def change_state
      @state = @states.next
      changed
      notify_observers @state
    end

    def kill_safe
      @state = -1
      changed
      notify_observers @state
      sleep 0.1
      kill #method of the ancestor
    end
  end


  class ThreadsManager
    #If a process receives SIGTERM it shutdowns and kills all its threads
    def self.kill_safe
      self.threads_list.each do |t|
        if t.kind_of? SafeKilledThread
          t.kill_safe
        else #standard thread
          t.kill
        end
      end
      exit 0
    end

    #Creates a nedeed quantity of threads, makes itself observed and waits for shutdown.
    def self.start(threads_count)
      pid = fork { self.child_process threads_count }
      self.detach_process(pid)
      pid
    end

    private

    def self.child_process(threads_count)
      raise ArgumentError, "Count must be > 0, but got #{threads_count}" if threads_count < 1

      trap("TERM") do
        self.kill_safe
      end

      threads_count.times do
        t = self.new_safekilled_thread
        bind_to_observer(t)
      end

      self.join_all
    end


    def self.threads_list
      Thread.list.collect { |t| t if t != Thread.main }.compact
    end

    def self.join_all
      Thread.list.each { |t| t.join }
    end

    def self.bind_to_observer(thread)
      ThreadStateObserver.new(thread)
    end

    def self.detach_process(pid)
      Process.detach(pid)
    end

    def self.new_safekilled_thread
      SafeKilledThread.new
    end
  end
end