require "socket"
require "logger"
require "./memcached/*"

module Memcached
  @@logger = Memcached.new_logger

  class RecoverableError < Exception; end
  class UnrecoverableError < Exception; end

  class BadVersionException < RecoverableError; end
  class NotFoundError < RecoverableError; end

  class EOFError < UnrecoverableError; end
  class ReadError < UnrecoverableError; end
  class WriteError < UnrecoverableError; end
  class FlushError < UnrecoverableError; end

  #:nodoc:
  def self.logger
    @@logger
  end

  def self.new_logger : Logger
    logger = Logger.new(STDOUT)
    if ENV["DEBUG"]?
      logger.level = Logger::INFO
    else
      logger.level = Logger::ERROR
    end
    logger
  end
end
