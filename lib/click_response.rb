require File.join(File.dirname(__FILE__), 'response_base')

class ClickResponse < ResponseBase
  attr_accessor :mean_ordinality, :click_target

  def initialize(options = {})
    super(options)
    @mean_ordinality = options[:mean_ordinality]
    @click_target    = options[:click_target]
  end
end
