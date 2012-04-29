#coding=utf-8
root = File.dirname(__FILE__)
$:.unshift(root) unless $:.include?(root)

require "logger"
require "json"
require "eventmachine"
require "em-http-request"

require "threads_manager"


$log = Logger.new($stderr)


#Класс: Сервер Менеджер процесссов
#
#Он принимает комманды на порт PORT:
#  /^CREATE PROCESS WITH (\d+) WORKERS$/ - создать процесс с N тредами
#  /^TERMINATE PROCESS (\d+)$/ - безопасно завершить процесс, выполнив работу по завершению каждого воркера
#  /^KILL PROCESS (\d+)$/ - жестко прибить процесс со всеми воркерами
#  /^UPDATE (\d+)#(\d+) STATE (-?\d+)$/ - обновить состояния для треда X процесса Y
#
#После получения любой из команд он обновляен состояние тредов и отсылает инф-цию о состоянии по http на NOTIFY_URL

class ProcessManagerServer < EventMachine::Connection
  include EventMachine::Protocols::LineText2

  def initialize(pids)
    @pids = pids
    super
  end

  #Обработать команду для сервера процессов
  def receive_line(command)
    $log.debug "GOT COMMAND: #{command}"
    
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
          $log.error "INVALID COMMAND"
      end

    rescue Exception => e
      send_data "ERROR: #{e.message} #{e.backtrace.inspect}\n"
    else
      send_data "OK\n"
      notify_clients
    end

    close_connection_after_writing
  end

  #Создать новый процесс
  def create_process(workers_count)
    pid = start_threads(workers_count)
    @pids[pid] = {}
  end

  #Безопасно завершить процесс, по одному убив все воркеры. Отсылает SIGTERM процессу
  def terminate(pid)
    process_kill(15, pid)
  rescue Exception => e
    $log.error "#{e.message}\n#{e.backtrace.inspect}"
  end

  #Просто убить процесс. Отсылает SIGKILL
  def kill(pid)
    process_kill(9, pid) #SIGKILL
    @pids.delete(pid)
  rescue Exception => e
    $log.error "#{e.message}\n#{e.backtrace.inspect}"
  end

  #Обновить состояние воркеров процесса
  def update(pid, thread, state)
    @pids[pid] ||= {}

    if state.to_i > 0
      @pids[pid][thread] = state
    else
      @pids[pid].delete(thread)
      @pids.delete pid if @pids[pid].empty?
    end
  end

  #Отправить уведомление об изменившимся состоянии веб-серверу по http
  def notify_clients
    http_post body: {data: @pids.to_json}
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
    http.errback { $log.error "Cannot post data to #{NOTIFY_URL}" }
    http
  end


end

if __FILE__ == $0
  EventMachine::run do
    puts "Start process manager server on #{MASTER_PROCCESS[:host]}:#{MASTER_PROCCESS[:port]}"
    pids = {} #shared beetween requests
    EM::start_server MASTER_PROCCESS[:host], MASTER_PROCCESS[:port], ProcessManagerServer, pids

    trap "TERM" do
      ThreadsManager.soft_kill
    end
  end
end
