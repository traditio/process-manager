require 'rubygems'
require 'sinatra/base'
require 'eventmachine'
require 'em-websocket'

require 'erb'
require 'json'
require 'logger'
require 'sinatra/async'

$log = Logger.new($stdout)


module ProcessManagerClient
  def initialize request, command
    @command = command
    @req = request
  end

  def post_init
    $log.debug "Send data to server #{@command}"
    send_data @command
    close_connection_after_writing
  end

  def unbind
    if error?
      @req.body "ERROR: #{@command}"
    else
      @req.body "OK: #{@command}"
    end
  end

end

class WebManager < Sinatra::Base
  register Sinatra::Async
  set :root, File.dirname(__FILE__)

  aget '/' do
    redirect '/index.html'
  end


  aget '/delay/:n' do |n|
    EM.add_timer(n.to_i) { body { "delayed for #{n} seconds" } }
  end

  aget '/stop/:pid/' do |pid|
    halt 404 unless pid.match(/^\d+$/)
    EventMachine.connect '127.0.0.1', 7001, ProcessManagerClient, self, "TERMINATE PROCESS #{pid}\n"
  end
  aget '/kill/:pid/' do |pid|
    halt 404 unless pid.match(/^\d+$/)
    EventMachine.connect '127.0.0.1', 7001, ProcessManagerClient, self, "KILL PROCESS #{pid}\n"
  end

  aget '/create/' do

    unless params.key?('workers') and params['workers'].match(/^\d+$/)
      $log.debug 'bad request'
      halt 400, '400 Bad Request'
    end

    command = "CREATE PROCESS WITH #{params['workers']} WORKERS\n"
    $log.debug command
    EventMachine.connect '127.0.0.1', 7001, ProcessManagerClient, self, command

  end


end

module ThreadStateListener
  include EventMachine::Protocols::LineText2

  def initialize(channel, hash)
    @channel = channel
    @hash = hash
  end

  def receive_line(line)
    close_connection

    if line.match(/UPDATE (\d+)#(\d+) STATE (\d+)/)
      pid, thread, state = Regexp::last_match.captures
      if not @hash.has_key? pid
        @hash[pid] = Hash.new()
      end
      @hash[pid][thread] = state
    elsif line.match(/DELETE (\d+)#(\d+)/)
      pid, thread = Regexp::last_match.captures
      if @hash.has_key?(pid)
        if @hash[pid].has_key?(thread)
          @hash[pid].delete(thread)
        end
        if @hash[pid].length == 0
          @hash.delete(pid)
        end
      end

    else
      $log.error "Recived invalid message abouth thread state: #{line}"
    end

    @channel.push @hash.to_json
  end
end


EventMachine.run do
  processes = Hash.new
  channel = EventMachine::Channel.new

  EventMachine::WebSocket.start(:host => "127.0.0.1", :port => 7002, :debug => false) do |ws|
    ws.onopen {
      @sid = channel.subscribe { |msg|
        ws.send msg
      }
    }
    ws.onclose {
      channel.unsubscribe (@sid)
    }
  end
  EM::start_server '127.0.0.1', 7000, ThreadStateListener, channel, processes
  WebManager.run!({:port => 3000})
end