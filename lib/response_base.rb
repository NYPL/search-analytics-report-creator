class ResponseBase
  attr_accessor :search_term, :action, :total_events, :unique_events, :dimensions

  def initialize(options = {})
    @search_term   = options[:search_term]
    @action        = options[:action]
    @total_events  = options[:total_events ]
    @unique_events = options[:unique_events]
    @dimensions    = options[:dimensions]
  end

end
