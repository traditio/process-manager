require "logger"
logger = Logger.new($stdout)
module Foo
  def self.bar
    hello = "he the" +
        "fejkfejh"

    logger.info hello
  end
end

Foo.bar