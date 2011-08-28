require "observer"
require "socket"
require "timeout"
require "logger"

PROCESS_MANAGER_HOST= '127.0.0.1'
PROCESS_MANAGER_PORT= 7000
SOCKET_TIMEOUT = 5


$log = Logger.new($stdout)


#Как поток меняет свое состояние, отсылаем сообщение на сокет.

class ThreadStateObserver

  def initialize(thread)
    @thread = thread
    @thread.add_observer(self)
  end

  def update(state)
    begin
      timeout(1) do
        conn = create_connection
        msg = (state > 0) ? "UPDATE #{@thread.thread_id} STATE #{state}" : "DELETE #{@thread.thread_id}"
        conn.puts msg
        conn.close
      end
    rescue Timeout::Error
      $log.error "Can't send thread #{@thread.thread_id} state to #{PROCESS_MANAGER_HOST}:#{PROCESS_MANAGER_PORT}, timeout exceed"
    end
  end

  def create_connection
    TCPSocket.open(PROCESS_MANAGER_HOST, PROCESS_MANAGER_PORT)
  end

end


#Класс потока, который может безопасно завершить свою работу,
#например, закрыть открытые ресурсы.
#Этот класс потоко меняет свои состояние по кругу ч/з случ. промежуток времени
#и он оповещает об этом всех своих наблюдателей (observers)

class SafeKilledThread < Thread
  include Observable # наблюдаемый объект

  attr_reader :thread_id

  # Потк меняет свое состояние каждое кол-во секунд между этими значениями
  CHANGE_STATE_EVERY_SEC_MIN = 1
  CHANGE_STATE_EVERY_SEC_MAX = 5

  # Вся абстрактная работа определена в методе job() поэтому
  # мы не передаем блок кода в конструктор
  # i: порядковый номер треда, из него строится идентификатор

  def initialize

    @thread_id = "#{$$}##{object_id}"
    $log.debug 'Start new thread '+@thread_id
    @state = 0
    super do
      job()
    end
  end

  #Абстрактная работа, которую выполняет поток.
  #Он меняет свое состояние (от 1 до 5) по кругу через случ. промежуток времени

  def job
    loop do
      notify_observers(@state)
      delay = CHANGE_STATE_EVERY_SEC_MIN + rand(CHANGE_STATE_EVERY_SEC_MAX - 1)
      sleep delay
      @state = (@state == 5) ? 1 : (@state + 1)
      changed
    end
  end

  # Функция мягкого завершения треда

  def soft_kill
    @state = -1
    changed
    notify_observers(@state)
    kill()
  end

end


#Если процесс получает SIGTERM он корректно завершает свою работу,
#"правильно" убивая все потоки.


def soft_kill
  threads = Thread.list.collect {|t| t if t != Thread.main}
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

def start_threads(count)

  pid = fork do

    trap("TERM") do
      soft_kill
    end

    if count < 1
      raise ArgumentError, "Count must be > 0, but got #{count}"
    end

    count.times do
      t = SafeKilledThread.new
      ThreadStateObserver.new(t)
    end
    Thread.list.each { |t| t.join() }
  end
  Process.detach(pid)
  pid
end


# только для отладки

if __FILE__ == $0
  start_threads(5)
end
