require File.join(File.dirname(__FILE__), 'response_base')
Dir[File.join(File.dirname(__FILE__), 'report_generators', '*.rb')].each {|file| require file }

class QueryResponse < ResponseBase
end
