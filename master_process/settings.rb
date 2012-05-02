require "logger"

module MasterProcess
  PROCESS_MANAGER_HOST = "127.0.0.1"
  PROCESS_MANAGER_PORT = 7001
  SOCKET_TIMEOUT = 1 #seconds

  #Threads change their state with time in this range.
  CHANGE_STATE_EVERY_SEC_MIN = 1 #seconds
  CHANGE_STATE_EVERY_SEC_MAX = 5 #seconds

  NOTIFY_URL = "http://localhost:3000/update/"
  HOST = "127.0.0.1"
  PORT = 7001

  def self.logger
    @logger ||= Logger.new($stderr)
  end
end






