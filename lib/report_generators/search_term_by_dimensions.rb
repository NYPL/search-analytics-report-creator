require 'date'
require 'set'

require File.join(__dir__, '..', 'google_api_client')
require File.join(File.absolute_path(__dir__), '..', 'json_logger')

require File.join(__dir__, '..', '..', 'config', 'app')

class SearchTermByDimensions
  attr_accessor :queries, :clicks, :dimension_data
  attr_reader :csv_headers

  def initialize(options = {})
    @google_api_client  = GoogleApiClient.new(auth_file: options[:auth_file])
    @ga_profile_id = options[:ga_profile_id]
    @start_date    = options[:start_date]
    @end_date      = options[:end_date]
    @output        = options[:output]
    @google_parent_id = options[:google_parent_id]
    @dimension_data = options[:dimension_data] || []
    @queries       = []
    @clicks        = []
    @csv_headers   = _csv_headers
    @logger = JsonLogger.new.logger
  end

  def report_basename
    mapping = {
      'today'     =>  Date.today.strftime(),
      'yesterday' =>  (Date.today - 1).strftime()
    }

    real_start_date = mapping[@start_date] || @start_date
    real_end_date   = mapping[@end_date] || @end_date

    "output_#{real_start_date}_#{real_end_date}.csv"
  end

  def report_output_path
    (@output == "google-sheets") ? File.join(File.absolute_path('.'), self.report_basename) : File.join(File.absolute_path(@output), self.report_basename)
  end

  def get_events!()
    query_rows = get_query_rows
    click_rows = get_click_rows

    query_rows.each do |query_row|
      queries << QueryResponse.new({
        search_term: query_row.shift,
        action: query_row.shift,
        dimensions: dimensions_for_query_sent.map {|dim| [dim[:name], query_row.shift]}.to_h,
        total_events: query_row.shift.to_i,
        unique_events: query_row.shift.to_i,
      })
    end

    click_rows.each do |click_row|
      clicks << ClickResponse.new({
        search_term: click_row.shift,
        action: click_row.shift,
        dimensions: dimensions_for_clickthrough.map {|dim| [dim[:name], click_row.shift]}.to_h,
        total_events: click_row.shift.to_i,
        unique_events: click_row.shift.to_i,
        mean_ordinality: click_row.shift.to_f,
      })
    end
  end

  def dimensions_for_query_sent
    dimensions_for_event_type(QUERY_SENT)
  end

  def dimensions_for_clickthrough
    dimensions_for_event_type(CLICKTHROUGH)
  end

  def dimensions_for_event_type(event_type)
    @dimension_data.select {|dimension| dimension[:events].include? event_type}
  end
 
  def ga_dimensions_string_for_event_type(event_type)
    dimensions_for_event_type(event_type).map {|dimension| "ga:dimension#{dimension[:ga_index]}"}.join(',')
  end
  
  def process_data_for_term(term)
    events_processor = TermEventsProcessor.new(
      term: term, 
      dimensions: @dimension_data.map {|dim| dim[:name]},
      query_segments: query_events_for_term(term), 
      click_segments: click_events_for_term(term),
      query_sent_dimensions: dimensions_for_query_sent.map {|dim| dim[:name]},
    )
    events_processor.process
  end

  def click_events_for_term(term)
    clicks.find_all { |click| click.search_term == term }
  end

  def query_events_for_term(term)
    queries.find_all { |query| query.search_term == term }
  end

  def results_for_terms(query_terms)
    query_terms.inject([]) { |running_results, query_term| running_results.concat(process_data_for_term(query_term)) }
  end
    
  def generate_report!
    get_events!

    sorted_query_terms = queries.inject(Hash.new(0)) {|query_totals, query| 
      query_totals[query.search_term] += query.total_events
      query_totals
    }.to_a.sort_by { |term, count| [count, term] }.reverse.map {|query_total_pair| query_total_pair[0]}
    
    all_results = results_for_terms(sorted_query_terms)
    
    CSV.open(report_output_path, 'wb') do |csv|
      csv << csv_headers
      all_results.each_with_index { |row, i| csv << row.insert(1, i+1) }
    end

    if @output == "google-sheets"
      upload_to_drive
    end

  end

  def upload_to_drive
    drive_client = @google_api_client.drive_client

   # Upload a file
    metadata = GoogleApiClient::DRIVE_FILE.new(name: self.report_basename, mime_type: 'application/vnd.google-apps.spreadsheet')
    file = drive_client.create_file(metadata, upload_source: self.report_output_path, content_type: 'text/csv', supports_team_drives: true)
    drive_client.update_file(file.id, add_parents: @google_parent_id)

    filter_spreadsheet(file)
  end

  def filter_spreadsheet(file)
    sheets_client = @google_api_client.sheets_client
    spreadsheet = sheets_client.get_spreadsheet(file.id)

    requests = {
      requests: [
        {add_filter_view: {
          filter: {
            title: 'All Query Summary',
            range: {
              sheet_id: spreadsheet.sheets[0].properties.sheet_id
            },
            criteria: {
              '2': {
                hidden_values: ['Encore', 'DrupalSearch', 'BetaSearch']
              }
            }
          }
        }},
        {add_filter_view: {
          filter: {
            title: 'Encore — Header Search vs Browse',
            range: {
              sheet_id: spreadsheet.sheets[0].properties.sheet_id
            },
            criteria: {
              '2': {
                hidden_values: ['ALL', 'DrupalSearch', 'BetaSearch']
              },
              '3': {
                hidden_values: ['ALL', 'Unknown']
              }
            }
          }
        }},
        {add_filter_view: {
          filter: {
            title: 'Header Search',
            range: {
              sheet_id: spreadsheet.sheets[0].properties.sheet_id
            },
            criteria: {
              '2': {
                hidden_values: ['ALL']
              },
              '3': {
                hidden_values: ['ALL', 'EncoreSearchForm', 'Unknown']
              }
            }
          }
        }},
        {add_filter_view: {
          filter: {
            title: 'Unknown Where Searched From',
            range: {
              sheet_id: spreadsheet.sheets[0].properties.sheet_id
            },
            criteria: {
              '3': {
                hidden_values: ['ALL', 'HeaderSearch', 'EncoreSearchForm']
              }
            }
          }
        }}
      ]
    }

    sheets_client.batch_update_spreadsheet(file.id, requests, {})
  end

private

  def analytics_client
    @analytics_client ||= @google_api_client.analytics_client
  end

  def get_event_rows(event_type, start_index = 1, response_rows = [])
    response = analytics_client.get_ga_data(@ga_profile_id, @start_date, @end_date, 'ga:totalEvents,ga:uniqueEvents,ga:avgEventValue', dimensions: "ga:eventLabel,ga:eventAction,#{ga_dimensions_string_for_event_type(event_type)}", max_results: 10000, filters: "ga:eventCategory==Search;ga:eventAction==#{event_type}", sort: "ga:eventLabel", start_index: start_index)
    @logger.info("Paginated find: #{response_rows.length + (response.rows or []).length} of #{response.total_results} #{event_type} events")
    
    return [] if response.total_results == 0

    # This is the last iteration, add these rows and return
    if !response.next_link
      response_rows.concat(response.rows)
    else
      next_index = CGI.parse(URI.parse(response.next_link).query)["start-index"].first
      get_event_rows(event_type, next_index, response_rows.concat(response.rows))
    end

    response_rows
  end

  def get_click_rows
    get_event_rows(CLICKTHROUGH)
  end

  def get_query_rows
    get_event_rows(QUERY_SENT)
  end

  def _csv_headers
    headers = ['Search Term', 'Row Number']
    headers.concat(@dimension_data.map { |h| h[:title] })
    headers.concat(['Total Searches', 'Total Clicks', 'CTR', 'WCTR', 'Mean Ordinality'])
  end

end 

class TermEventsProcessor
  attr_accessor :term, :query_segments, :click_segments, :dimensions, :query_sent_dimensions

  def initialize(term:, dimensions:, query_segments:, click_segments:, query_sent_dimensions:)

    @term = term
    @query_segments = query_segments
    @click_segments = click_segments
    @dimensions = dimensions
    @query_sent_dimensions = query_sent_dimensions

  end

  def process
    process_data_for_dimensions(dimensions.dup)
  end

  def process_data_for_dimensions(dimensions, values: {})
    # Recursively find all permutations of values from requested report dimensions, 
    #   and, once all dimensions are specified, return a results row for those values

    return [data_row_for_values(values)] if dimensions.empty?

    # For the next dimension
    this_dimension = dimensions.shift

    # Find all possible values
    dimension_values = get_values(this_dimension)

    # Recursively call method with each dimension value in turn
    event_rows = dimension_values.inject([]) do |rows, value|

      rows.concat(
        process_data_for_dimensions(dimensions.dup, values: values.merge({this_dimension => value})).compact
      )
      
    end

    # Calculate the aggregate values for the dimension just iterated over
    this_dimension_index = @dimensions.index this_dimension
    values_for_aggregation = @dimensions.map { |dim|
      @dimensions.index(dim) < this_dimension_index ?
        [dim, values[dim]] :
        [dim, 'ALL']
    }.to_h

    event_rows << data_row_for_values(values_for_aggregation)

  end

  def get_values(dimension)
    # return all available values for the given dimension
    (
      click_segments.map {|segment| segment.dimensions[dimension]}.compact + 
      query_segments.map {|segment| segment.dimensions[dimension]}.compact
    ).uniq.sort_by(&:to_s)
  end

  def segments_for_values(segment_type, values)
    # return the segments of specified type (query or click) matching dimension values given
    self.send(segment_type).find_all do |segment|
      # return all segments which match the appropriate values
      values.each_pair.all? do |dimension, value|
        value == 'ALL' or segment.dimensions[dimension] == value
      end
    end
  end

  def data_row_for_values(values)
    # for a set of dimension values, find matching query and click segments, and calculate 
    #   total queries, clicks CTR, WCTR, mean ordinality and return row with these values
    matching_query_segments = segments_for_values(:query_segments, values)
    matching_click_segments = segments_for_values(:click_segments, values)
    return nil if matching_query_segments.empty? and matching_click_segments.empty?

    # If the non-aggregated dimension values include non-query_sent dimensions total_queries should be nil
    non_aggregated_dimensions = values.keys.reject {|dim| values[dim] == 'ALL'}
    total_queries = 
      non_aggregated_dimensions.to_set.subset?(query_sent_dimensions.to_set) ? 
      matching_query_segments.inject(0) { |sum, segment| sum += segment.total_events } :
      nil
    total_clicks = matching_click_segments.inject(0) { |sum, segment| sum += segment.total_events }

    row = []
    row << term

    row.concat dimensions.map { |dimension| values[dimension] }
    
    row << total_queries
    row << total_clicks

    # Will enter nil if total_queries is 0
    row << ((total_clicks.to_f / total_queries).round(2) if total_queries.to_i > 0)
    row << ((total_clicks.to_f / total_queries / total_queries).round(4) if total_queries.to_i > 0)
    
    row << (self.class.mean_ordinality_over_segments(matching_click_segments.map {|segment| [segment.total_events, segment.mean_ordinality]})).round(1)
  end

  def self.mean_ordinality_over_segments(click_ordinality_arrays)
    # Take pairs of the average ordinality and the number clicks and calculate mean ordinality for them
    ordinality_fraction = click_ordinality_arrays.inject({ordinality_total: 0, click_total: 0}) do |sum, click|
      sum[:ordinality_total] += click[0] * click[1]
      sum[:click_total] += click[0]
      sum
    end

    return 0.0 if ordinality_fraction[:click_total] == 0

    ordinality_fraction[:ordinality_total] / ordinality_fraction[:click_total] rescue 0
  end

end
