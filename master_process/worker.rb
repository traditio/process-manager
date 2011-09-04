require "observer"
require "socket"
require "timeout"
require "logger"


PROCESS_MANAGER = {:host => '127.0.0.1', :port => 7001}
SOCKET_TIMEOUT = 5


$log = Logger.new($stdout)


#Наблюдатель за состоянием тредов.
#При измении состояния треда, класс отправляет на сокет серверу менеджера процессов
#уведомление о новом состоянии.
#Если истекает таймаут (не может соединиться с сервером), то пишет ошибку в лог.
class ThreadStateObserver

  def initialize(thread)
    @thread = thread
    @thread.add_observer(self)
  end

  def update(state)
    begin
      timeout(1) do
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


#Класс потока, который может безопасно завершить свою работу,
#например, закрыть открытые ресурсы.
#Этот класс потоко меняет свои состояние по кругу ч/з случ. промежуток времени
#и он оповещает об этом всех своих наблюдателей (observers)

class SafeKilledThread < Thread
  include Observable # наблюдаемый объект

  attr_reader :thread_id, :state

  # Потк меняет свое состояние каждое кол-во секунд между этими значениями
  CHANGE_STATE_EVERY_SEC_MIN = 1
  CHANGE_STATE_EVERY_SEC_MAX = 5

  # Вся абстрактная работа определена в методе job() поэтому
  # мы не передаем блок кода в конструктор
  # i: порядковый номер треда, из него строится идентификатор

  def initialize
    @thread_id = "#{$$}##{object_id}"
    $log.debug 'Start new thread '+@thread_id
    @state = 0 # если @state < 0 - то тред в процессе "умирания"
    super do
      loop do
        job()
      end
    end
  end

  #Абстрактная работа, которую выполняет поток.
  #Он меняет свое состояние (от 1 до 5) по кругу через случ. промежуток времени
  def job
    notify_observers(@state)
    sleep CHANGE_STATE_EVERY_SEC_MIN + rand(CHANGE_STATE_EVERY_SEC_MAX - 1)
    @state = (@state == 5) ? 1 : (@state + 1)
    changed
  end

  # Функция мягкого завершения треда
  def soft_kill
    # какая-нибудь работа по безопасному завершению треда здесь
    @state = -1
    changed
    notify_observers(@state)
    sleep 0.1
    kill()
  end

end

class ThreadsManager

  #Если процесс получает SIGTERM он корректно завершает свою работу,
  #"правильно" убивая все потоки.
  def self.soft_kill
    threads = self.threads_list
    threads.compact!
    threads.each do |t|
      if t.kind_of? SafeKilledThread
        t.soft_kill()
      else
        t.kill()
      end
    end
    exit(0)
  end

  # Запускает нужное кол-во потоков, присваивает им наблюдателей и ждет завершения работы
  def self.start(threads_count)

    pid = fork do
      self.child_process(threads_count)
    end
    self.detach_process(pid)
    pid
  end

  private

  #Код для дочернего процесса. Запускает N безопасно убиваемых тредов и ждет SIGTERM для их остановки.
  def self.child_process(threads_count)
    trap("TERM") do
      self.soft_kill
    end

    if threads_count < 1
      raise ArgumentError, "Count must be > 0, but got #{threads_count}"
    end

    threads_count.times do
      t = self.new_safekilled_thread
      bind_to_observer(t)
    end
    self.join_threads
  end


  def self.threads_list
    Thread.list.collect { |t| t if t != Thread.main }
  end

  def self.join_threads
    Thread.list.each { |t| t.join() }
  end

  def self.bind_to_observer(tread)
    ThreadStateObserver.new(tread)
  end

  def self.detach_process(pid)
    Process.detach(pid)
  end

  def self.new_safekilled_thread
     SafeKilledThread.new
  end
end
