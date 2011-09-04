require 'rubygems'
require 'sinatra/base'
require 'eventmachine'
require 'em-websocket'

require 'erb'
require 'json'
require 'logger'
require 'sinatra/async'

$log = Logger.new($stdout)
$channel = EventMachine::Channel.new


WEB_INTERFACE = {:host => "localhost", :port => 3000}
WEBSOCKETS = {:host => "localhost", :port => 10081}

#Этот класс предназначен для отправки запросов на сокет из
#асинхронной синатры. Получет ответ от сокета и синатра возвращает
#этот ответ по HTTP.
class ProcessManagerClient < EventMachine::Connection

  include EventMachine::Protocols::LineText2

  def initialize request, command
    @command = command
    @req = request
  end

  def post_init
    $log.info 'ProcessManagerClient post_init'
    send_data @command
  end

  def receive_line(response)
    $log.debug "ProcessManagerClient receive_line - #{response}"
    @req.body response
  end

  def unbind
    $log.debug "ProcessManagerClient unbind, error? #{error?}"
    @req.body "ERROR: #{@command}" if error?
  end


end


#Асинхронная синатра. Замечательно работает с EventMachine не блокируя поток.
class WebManager < Sinatra::Base
  register Sinatra::Async
  set :root, File.dirname(__FILE__)

  def initialize *args
    @channel = $channel
    super
  end

  # отдаем главную страничку (она статическая)
  aget '/' do
    redirect '/index.html'
  end

  # безопасная остановка процесса
  aget '/terminate/:pid/' do |pid|
    ahalt 404 unless pid.match(/^\d+$/)
    $log.info "TERMINATE #{pid}"
    send_command_to_process_manager("TERMINATE PROCESS #{pid}\n")
  end

  # убийство процесса
  aget '/kill/:pid/' do |pid|
    ahalt 404 unless pid.match(/^\d+$/)
    $log.info "KILL #{pid}"
    send_command_to_process_manager("KILL PROCESS #{pid}\n")
  end

  # создание процесса с N воркерами
  aget '/create/' do
    ahalt 400, '400 Bad Request' unless params.key?('workers') and params['workers'].match(/^\d+$/)
    $log.info "CREATE #{params['workers']}"
    send_command_to_process_manager("CREATE PROCESS WITH #{params['workers']} WORKERS\n")
  end

  # сюда отправляет сообщения сервер менеджера процессов.
  # По уму, в продакшне, надо разрешать принимать соединения на этот URL
  # только от определенного IP (на котором работает менеджер процессов) или по ключу.
  apost '/update/' do
    ahalt 400, '400 Bad Request' unless params.key?('data')
    $log.info "UPDATE #{params.inspect}"
    @channel.push params['data']
    body ""
  end

  private

  def send_command_to_process_manager(command)
    EventMachine.connect '127.0.0.1', 7001, ProcessManagerClient, self, command
  end

end


EventMachine.run do

  # Обновление информации на клиенте осуществляется через вебсокеты
  # Может следовало сделать long-pooling в целях совместимости, но никто не
  # запрещает нам экспериментировать с new technologies в тестовых заданиях, верно?
  EventMachine::WebSocket.start(WEBSOCKETS) do |ws|
    ws.onopen {
      @sid = $channel.subscribe { |msg|
        ws.send msg
      }
    }
    ws.onclose {
      $channel.unsubscribe (@sid)
    }
    ws.onerror { |error|
      $log.error error
    }

  end

  WebManager.run!(WEB_INTERFACE) # асинхронная сината
end