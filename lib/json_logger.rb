require 'logger'
require 'json'

# Logs to stdout. All the time.
class JsonLogger
  attr_reader :logger
  def initialize(options = {log_level: :info})
    @logger = Logger.new(STDOUT) # or retrieve the default application logger
    @logger.level = Object.const_get "Logger::#{options[:log_level].to_s.upcase}"
    @logger.formatter = proc do |severity, datetime, progname, msg|
      JSON.fast_generate({level: severity, timestamp: datetime, message: msg}) << "\n"
    end
  end
end