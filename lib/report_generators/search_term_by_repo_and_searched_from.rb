class SearchTermByRepoAndSearchedFrom

  def initialize(options = {})
    @auth_file     = options[:auth_file]
    @ga_profile_id = options[:ga_profile_id]
    @start_date    = options[:start_date]
    @end_date      = options[:end_date]
    @output        = options[:output]
  end

  def generate_report!
    scopes = ['https://www.googleapis.com/auth/analytics.readonly']
    auth = Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: File.open(@auth_file, 'r'), scope: scopes)
    stats = Google::Apis::AnalyticsV3::AnalyticsService.new
    stats.authorization = auth

    query_response = stats.get_ga_data(@ga_profile_id, @start_date, @end_date, 'ga:totalEvents,ga:uniqueEvents', dimensions: 'ga:eventLabel,ga:eventAction,ga:dimension1,ga:dimension2', max_results: 10000, filters: "ga:eventCategory==Search;ga:eventAction==QuerySent", sort: "-ga:totalEvents")
    click_response = stats.get_ga_data(@ga_profile_id, @start_date, @end_date, 'ga:totalEvents,ga:uniqueEvents,ga:avgEventValue', dimensions: 'ga:eventLabel,ga:eventAction,ga:dimension1,ga:dimension2', max_results: 10000, filters: "ga:eventCategory==Search;ga:eventAction==Clickthrough", sort: "ga:eventLabel")

    queries = []
    clicks  = []

    if query_response.rows
      query_response.rows.each do |query_row|
        queries << QueryResponse.new({
          search_term: query_row[0],
          action: query_row[1],
          searched_from: query_row[2],
          searched_repo: query_row[3],
          total_events: query_row[4].to_i,
          unique_events: query_row[5].to_i
        })
      end
    end

    if click_response.rows
      click_response.rows.each do |click_row|
        clicks << ClickResponse.new({
          search_term: click_row[0],
          action: click_row[1],
          searched_from: click_row[2],
          searched_repo: click_row[3],
          total_events: click_row[4].to_i,
          unique_events: click_row[5].to_i,
          mean_ordinality: click_row[6].to_f,
        })
      end
    end

    output_file_path = File.join(File.absolute_path(@output), "output_#{@start_date}_#{@end_date}.csv")

    CSV.open(output_file_path, 'wb') do |csv|
      headers = ['Search Term', 'Searched Repo', 'Searched From', 'Total Searches', 'Total Clicks', 'CTR', 'WCTR', 'Mean Ordinality']
      csv << headers

      all_query_terms = queries.map(&:search_term).uniq
      all_query_terms.each do |query_term|

        all_queries_for_this = queries.find { |query| query.search_term == query_term }
        all_clicks_for_this = clicks.find_all { |click| click.search_term == query_term }

        # Calculate data for the per repo rows
        all_clicks_for_this.group_by(&:searched_repo).each do |searched_repo, click_events_by_from|
          click_events_by_from.each do |clicks_from|
            row = []
            row << query_term
            row << clicks_from.searched_repo
            row << clicks_from.searched_from

            matching_query_event =  queries.find { |query| query.search_term == query_term && query.searched_from == clicks_from.searched_from && query.searched_repo == clicks_from.searched_repo }
            row << matching_query_event.total_events
            row << clicks_from.total_events
            row << '%.2f' % ((clicks_from.total_events.to_f / matching_query_event.total_events) * 100)
            row << '%.2f' % clicks_from.mean_ordinality
            csv << row
          end

          sum_for_searched_repo_row = []
          sum_for_searched_repo_row << query_term
          sum_for_searched_repo_row << searched_repo
          sum_for_searched_repo_row << "ALL"


          all_queries_for_searched_repo = queries.find_all { |query| 
            query.search_term == query_term && query.searched_repo == searched_repo}

          # Total searches
          total_searches = all_queries_for_searched_repo.inject(0) { |sum, query| 
            sum + query.total_events 
          }
          sum_for_searched_repo_row << total_searches

          # Total clicks
          total_clicks = click_events_by_from.inject(0) {|sum, click| sum + click.total_events }
          sum_for_searched_repo_row << total_clicks

          # CTR
          sum_for_searched_repo_row << '%.2f' % ((total_clicks.to_f / total_searches) * 100)

          # Mean Ordinality
          all_ordinality = (click_events_by_from.inject(0) {|sum, click| sum + click.mean_ordinality }.to_f) / click_events_by_from.length
          sum_for_searched_repo_row << ('%.2f' % (all_ordinality))

          csv << sum_for_searched_repo_row
        end

        # Calculate data for the searched from rows
        all_clicks_for_this.group_by(&:searched_from).each do |searched_from, click_events_by_repo|
          click_events_by_repo.each do |repo_clicks|
            row = []
            row << query_term
            row << repo_clicks.searched_repo
            row << repo_clicks.searched_from

            matching_query_event =  queries.find { |query| query.search_term == query_term && query.searched_from == repo_clicks.searched_from && query.searched_repo == repo_clicks.searched_repo }
            row << matching_query_event.total_events
            row << repo_clicks.total_events
            row << '%.2f' % ((repo_clicks.total_events.to_f / matching_query_event.total_events) * 100)
            row << '%.2f' % repo_clicks.mean_ordinality
            csv << row
          end

          sum_for_searched_from_row = []
          sum_for_searched_from_row << query_term
          sum_for_searched_from_row << "ALL"
          sum_for_searched_from_row << searched_from


          all_queries_for_searched_from = queries.find_all {|query| query.search_term == query_term && query.searched_from == searched_from}

          # Total searches
          total_searches = all_queries_for_searched_from.inject(0) { |sum, queries| 
            sum + queries.total_events 
          }
          sum_for_searched_from_row << total_searches

          # Total clicks
          total_clicks = click_events_by_from.inject(0) {|sum, clicks| sum + clicks.total_events }
          sum_for_searched_from_row << total_clicks

          # CTR
          sum_for_searched_from_row << '%.2f' % ((total_clicks.to_f / total_searches) * 100)

          # Mean Ordinality
          all_ordinality = (click_events_by_from.inject(0) {|sum, click| sum + click.mean_ordinality }.to_f) / click_events_by_from.length
          sum_for_searched_from_row << ('%.2f' % (all_ordinality))

          csv << sum_for_searched_from_row
        end

        sum_for_term_row = []

        sum_for_term_row << query_term
        sum_for_term_row << "ALL"
        sum_for_term_row << "ALL"

        total_queries = all_queries_for_this.inject(0) { |sum, queries_per_segment| 
          sum + queries_per_segment.total_events
        }
        sum_for_term_row << total_queries

        total_clicks = all_clicks_for_this.inject(0) { |sum, clicks_per_segment|
          sum + clicks_per_segment.total_events
        }
        sum_for_term_row << total_clicks

        sum_for_term_row << '%.2f' % ((total_clicks.to_f / total_queries) * 100)

        # TODO — don't think this is right
        all_ordinality = (click_events_by_from.inject(0) {|sum, click| sum + click.mean_ordinali
ty }.to_f) / click_events_by_from.length

      end
    end
  end

  @dimensions = [:searched_repo, :searched_from]

  def process_data_for_segments_of_type(segment_dimension) 
    all_clicks_for_this.group_by(&segment_dimension).each do |segment, click_events_by_segment|
      click_events_by_segment.sort { |x,y| 
        [x.values_at(**dimensions)] <=> [y.values_at(**dimensions)]
      }.each do |clicks_segment|

        row = []
        row << query_term

        dimensions.each do |dimension|
          row << clicks_segment.send(dimension)
        end

        matching_queries_segment =  query_segments.find { |queries_segment| 
          queries_segment.search_term == clicks_segment.search_term &&
          queries_segment.searched_from == clicks_segment.searched_from &&
          queries_segment.searched_repo == clicks_segment.searched_repo 
        }
       
        row << matching_queries_segment.total_events
        row << clicks_segment.total_events
        row << '%.2f' % ((clicks_segment.total_events.to_f / matching_queries_segment.total_events) * 100)
        row << '%.2f' % clicks_segment.mean_ordinality
        csv << row
      end

      sum_for_segment_row = []
      sum_for_segment_row << query_term
      dimensions.each do |dimension|
        sum_for_segment_row << dimension == segment_dimension ? "ALL" : dimension
      end

      all_query_segments_for_this_segment = query_segments.find_all { |queries_segment| 
        queries_segment.search_term == query_term && 
        queries_segment.send(segment_dimension) == segment
      }

      # Total searches
      total_searches = all_query_segments_for_this_segment.inject(0) { |sum, queries_segment| 
        sum + queries_segment.total_events 
      }
      sum_for_segment_row << total_searches

      # Total clicks
      total_clicks = click_events_by_segment.inject(0) {|sum, clicks_segment| sum + clicks_segment.total_events }
      sum_for_segment_row << total_clicks

      # CTR
      sum_for_segment_row << '%.2f' % ((total_clicks.to_f / total_searches) * 100)

      # Mean Ordinality
      all_ordinality = (click_events_by_from.inject(0) {|sum, click| sum + click.mean_ordinality }.to_f) / click_events_by_from.length
      sum_for_segment_row << ('%.2f' % (all_ordinality))

      csv << sum_for_segment_row
    end

  end
end
