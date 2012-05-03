#coding=utf-8
root = File.dirname(__FILE__)
$:.unshift(root) unless $:.include?(root)

require "sinatra/base"
require "eventmachine"
require "em-websocket"
require "erb"
require "json"
require "logger"
require "sinatra/async"

require "settings"


module WebManager

  #This class is for requests sending to socket from async Synatra. It gets
  #a response from the socket and sends this response via HTTP
  class ProcessManagerClient < EventMachine::Connection
    include EventMachine::Protocols::LineText2

    def initialize(request, command)
      @command = command
      @req = request
    end

    def post_init
      send_data @command
    end

    def receive_line(response)
      @req.body(response)
    end

    def unbind
      @req.body("ERROR: #@command") if error?
    end
  end


  #Non-blocking HTTP server
  class WebManager < Sinatra::Base
    register Sinatra::Async
    set :root, File.dirname(__FILE__)

    #Main page. Static HTML.
    get "/" do
      redirect "/index.html"
    end

    #Safe process terminating
    get %r{/terminate/(\d+)/} do |pid|
      logger.info("TERMINATE #{ pid }")
      send_command_to_process_manager("TERMINATE PROCESS #{ pid }\n")
      body "OK"
    end

    #Process killing
    get %r{/kill/(\d+)/} do |pid|
      logger.info("KILL #{ pid }")
      send_command_to_process_manager("KILL PROCESS #{ pid }\n")
      body "OK"
    end

    #Creating of the process with 7 threads
    get "/create/" do
      ahalt 400, "400 Bad Request" unless params["workers"].to_s.match(/\A\d+\z/)
      logger.info("CREATE #{ params["workers"] }")
      send_command_to_process_manager("CREATE PROCESS WITH #{ params["workers"] } WORKERS\n")
      body "OK"
    end

    #Messages are send here by the process manager
    post "/update/" do
      ahalt 400, "400 Bad Request" unless params.key?("data")
      logger.info("UPDATE #{ params.inspect }")
      channel.push(params["data"])
      body "OK"
    end

    private

    def logger
      self.class.logger
    end

    def channel
      self.class.channel
    end

    def send_command_to_process_manager(command)
      EventMachine.connect(PROCESS_MANAGER[:host], PROCESS_MANAGER[:port], ProcessManagerClient, self, command)
    end
  end


  def self.main
    EventMachine.run do
      #Data refreshing in the browser goes through websockets
      channel = EventMachine::Channel.new
      logger = Logger.new($stdout)

      EventMachine::WebSocket.start WEBSOCKETS do |ws|
        ws.onopen { channel.subscribe { |msg| ws.send(msg) } }
        ws.onclose { channel.unsubscribe(@sid) }
        ws.onerror { |err| logger.error("Websockets error: #{ err.inspect }") }
      end

      WebManager.run!(WEB_INTERFACE.merge(channel: channel, logger: logger)) # asynchronous Sinatra
    end
  end
end


if __FILE__ == $0
  WebManager.main
end
