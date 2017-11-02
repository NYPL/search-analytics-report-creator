class ResponseBase
  attr_accessor :search_term, :action, :total_events, :unique_events,
                :searched_from, :searched_repo

  def initialize(options = {})
    @search_term   = options[:search_term]
    @action        = options[:action]
    @total_events  = options[:total_events ]
    @unique_events = options[:unique_events]
    @searched_from = options[:searched_from]
    @searched_repo = options[:searched_repo]
  end
end
