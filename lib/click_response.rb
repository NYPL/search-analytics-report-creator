require File.join(File.dirname(__FILE__), 'response_base')

class ClickResponse < ResponseBase
  attr_accessor :mean_ordinality

  def initialize(options = {})
    super(options)
    @mean_ordinality = options[:mean_ordinality]
  end
end
