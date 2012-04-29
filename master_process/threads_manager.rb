#coding=utf-8
root = File.dirname(__FILE__)
$:.unshift(root) unless $:.include?(root)

require "observer"
require "socket"
require "timeout"
require "logger"

require "settings"


$log = Logger.new($stderr)

#Threads state observer.
#When thread changes state it send a new state to Process manager through socket.
#If connections is unavailable, it logs an error.
class ThreadStateObserver

  def initialize(thread)
    @thread = thread
    @thread.add_observer(self)
  end

  def update(state)
    begin
      timeout(SOCKET_TIMEOUT) do
        conn = create_connection
        conn.puts "UPDATE #{@thread.thread_id} STATE #{state}"
        conn.close
      end
    rescue Timeout::Error
      $log.error "Can't send thread #{@thread.thread_id} state to #{PROCESS_MANAGER[:host]}:#{PROCESS_MANAGER[:port]}, timeout exceed"
    end
  end

  private

  def create_connection
    TCPSocket.open(PROCESS_MANAGER[:host], PROCESS_MANAGER[:port])
  end
end


#The thread which can kill itself safe.
#The tread changes it's state in cycle in specified time periods. He notifies Process Manager about state changing.
class SafeKilledThread < Thread
  include Observable
  attr_reader :thread_id, :state

  def initialize
    @thread_id = "#{$$}##{object_id}"
    $log.debug "Start new thread #{@thread_id}"
    @states = (1..5).cycle
    @state = 0 # if @state < 0 then thread during killing proccess
    
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

  def soft_kill
    @state = -1
    changed
    notify_observers @state
    sleep 0.1
    kill #method of ancestor
  end
end


class ThreadsManager
  #If process receives SIGTERM the it shutdowns, killing all his threads
  def self.soft_kill
    self.threads_list.each do |t|
      if t.kind_of? SafeKilledThread
        t.soft_kill
      else #standard thread
        t.kill
      end
    end
    exit 0
  end

  # Запускает нужное кол-во потоков, присваивает им наблюдателей и ждет завершения работы
  def self.start(threads_count)
    pid = fork { self.child_process threads_count }
    self.detach_process(pid)
    pid
  end

  private

  #Starts :threads_count threads and waiting for SIGTERM
  def self.child_process(threads_count)
    raise ArgumentError, "Count must be > 0, but got #{threads_count}" if threads_count < 1

    trap("TERM") do
      self.soft_kill
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
