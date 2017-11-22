require 'date'
require File.join(__dir__, '..', 'google_api_client')

require File.join(__dir__, '..', '..', 'config', 'app')

class SearchTermByDimensions
  attr_accessor :queries, :clicks, :dimension_data

  def initialize(options = {})
    @google_api_client  = GoogleApiClient.new(auth_file: options[:auth_file])
    @ga_profile_id = options[:ga_profile_id]
    @start_date    = options[:start_date]
    @end_date      = options[:end_date]
    @output        = options[:output]
    @google_parent_id = options[:google_parent_id]
    @dimension_data = options[:dimension_data]
    @queries       = []
    @clicks        = []
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
    analytics_client = @google_api_client.analytics_client

    query_response = analytics_client.get_ga_data(@ga_profile_id, @start_date, @end_date, 'ga:totalEvents,ga:uniqueEvents', dimensions: "ga:eventLabel,ga:eventAction,#{ga_dimensions_string_for_query_sent}", max_results: 10000, filters: "ga:eventCategory==Search;ga:eventAction==QuerySent", sort: "-ga:totalEvents")
    click_response = analytics_client.get_ga_data(@ga_profile_id, @start_date, @end_date, 'ga:totalEvents,ga:uniqueEvents,ga:avgEventValue', dimensions: "ga:eventLabel,ga:eventAction,#{ga_dimensions_string_for_clickthrough}", max_results: 10000, filters: "ga:eventCategory==Search;ga:eventAction==Clickthrough", sort: "ga:eventLabel")

    if query_response.rows
      query_response.rows.each do |query_row|
        queries << QueryResponse.new({
          search_term: query_row.shift,
          action: query_row.shift,
          dimensions: dimensions_for_query_sent.map {|dim| [dim[:name], query_row.shift]}.to_h,
          total_events: query_row.shift.to_i,
          unique_events: query_row.shift.to_i,
        })
      end
    end

    if click_response.rows
      click_response.rows.each do |click_row|
        clicks << ClickResponse.new({
          search_term: click_row.shift,
          action: click_row.shift,
          dimensions: dimensions_for_query_sent.map {|dim| [dim[:name], click_row.shift]}.to_h,
          total_events: click_row.shift.to_i,
          unique_events: click_row.shift.to_i,
          mean_ordinality: click_row.shift.to_f,
        })
      end
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
  
  def ga_dimensions_string_for_query_sent
    ga_dimensions_string_for_event_type(QUERY_SENT)
  end
  
  def ga_dimensions_string_for_clickthrough
    ga_dimensions_string_for_event_type(CLICKTHROUGH)
  end
  
  def process_data_for_term(term)
    events_processor = TermEventsProcessor.new(
      term: term, 
      dimensions: @dimension_data.map {|dim| dim[:name]},
      query_segments: query_events_for_term(term), 
      click_segments: click_events_for_term(term)
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
    query_terms.sort.inject([]) { |running_results, query_term| running_results.concat(process_data_for_term(query_term)) }
  end
    
  def generate_report!
    get_events!
    
    all_query_terms = queries.map(&:search_term).uniq
    all_results = results_for_terms(all_query_terms)
    
    CSV.open(report_output_path, 'wb') do |csv|
      headers = ['search term', 'searched repo', 'searched from', 'total searches', 'total clicks', 'ctr', 'wctr', 'mean ordinality']
      csv << headers
      all_results.each { |row| csv << row }
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
            title: 'all query summary',
            range: {
              sheet_id: spreadsheet.sheets[0].properties.sheet_id
            },
            criteria: {
              '2': {
                hidden_values: ['encore', 'drupalsearch', 'betasearch', 'beta search', 'catalog', 'sitesearch']
              }
            }
          }
        }},
        {add_filter_view: {
          filter: {
            title: 'encore — header search vs browse',
            range: {
              sheet_id: spreadsheet.sheets[0].properties.sheet_id
            },
            criteria: {
              '2': {
                hidden_values: ['all', 'drupalsearch', 'betasearch', 'beta search', 'catalog', 'sitesearch']
              },
              '3': {
                hidden_values: ['all', 'unknown']
              }
            }
          }
        }},
        {add_filter_view: {
          filter: {
            title: 'header search',
            range: {
              sheet_id: spreadsheet.sheets[0].properties.sheet_id
            },
            criteria: {
              '2': {
                hidden_values: ['all', 'catalog']
              },
              '3': {
                hidden_values: ['all', 'encoresearchform', 'unknown']
              }
            }
          }
        }},
        {add_filter_view: {
          filter: {
            title: 'unknown where searched from',
            range: {
              sheet_id: spreadsheet.sheets[0].properties.sheet_id
            },
            criteria: {
              '3': {
                hidden_values: ['all', 'headersearch', 'encoresearchform']
              }
            }
          }
        }}
      ]
    }

    sheets_client.batch_update_spreadsheet(file.id, requests, {})
  end

end

class TermEventsProcessor
  attr_accessor :term, :query_segments, :click_segments, :dimensions

  def initialize(term:, dimensions:, query_segments:, click_segments:)

    @term = term
    @query_segments = query_segments
    @click_segments = click_segments
    @dimensions = dimensions
  end

  def process
    process_data_for_dimensions(dimensions.dup)
  end

  def process_data_for_dimensions(dimensions, values: {})
    return [data_row_for_values(values)] if dimensions.empty?

    this_dimension = dimensions.shift

    dimension_values = get_values(this_dimension)

    event_rows = dimension_values.inject([]) do |rows, value|

      rows.concat(
        process_data_for_dimensions(dimensions.dup, values: values.merge({this_dimension => value})).compact
      )
      
    end

    calculate_aggregates_for_dimension!(this_dimension, values, event_rows)
    event_rows

  end

  def calculate_aggregates_for_dimension!(dimension, values, rows)
    aggregate_row = [term]
    aggregate_row.concat(@dimensions.map {|dim| values[dim] or 'ALL'})

    this_dimension_index = @dimensions.index dimension
    aggregate_row_dimension_values = aggregate_row[1, @dimensions.length]

    rows_to_aggregate = rows.select { |row| 
      row[1, @dimensions.length].map.with_index.all? { |value, i|
        next true if i == this_dimension_index
        value == aggregate_row_dimension_values[i]
      }
    }
    
    total_queries_index = dimensions.length + 1
    total_clicks_index = total_queries_index + 1
    aggregates = rows_to_aggregate.inject({total_queries: 0, total_clicks: 0}) { |agg, row|
      agg[:total_queries] += row[total_queries_index]
      agg[:total_clicks] += row[total_clicks_index]
      agg
    }
    
    aggregate_row << aggregates[:total_queries]
    aggregate_row << aggregates[:total_clicks]

    if aggregates[:total_queries] > 0
      ctr = aggregates[:total_clicks].to_f / aggregates[:total_queries]
      aggregate_row << ctr.round(2)
      aggregate_row << (ctr / aggregates[:total_queries]).round(4)
    else
      aggregate_row.concat([nil, nil])
    end

    aggregate_row << self.class.mean_ordinality_over_segments(rows_to_aggregate.map {|row| [row[total_clicks_index], row[-1]]}).round(1)

    rows << aggregate_row
    nil 
  end

  def get_values(dimension)
    (click_segments.map {|segment| segment.dimensions[dimension]} + query_segments.map {|segment| segment.dimensions[dimension]}).uniq.sort
  end

  def segments_for_values(segment_type, values)
    # For each event segment
      self.send(segment_type).find_all do |segment|
      # return all segments which match the appropriate values
      values.each_pair.all? do |dimension, value|
        segment.dimensions[dimension] == value
      end
    end
  end

  def data_row_for_values(values)
    matching_query_segments = segments_for_values(:query_segments, values)
    matching_click_segments = segments_for_values(:click_segments, values)

    return nil if matching_query_segments.empty? and matching_click_segments.empty?

    row = []
    row << term

    row.concat dimensions.map { |dimension| values[dimension] }
    
    total_queries = matching_query_segments.inject(0) { |sum, segment| sum += segment.total_events }
    row << total_queries

    total_clicks = matching_click_segments.inject(0) { |sum, segment| sum += segment.total_events }
    row << total_clicks

    # Will enter nil if total_queries is 0
    row << ((total_clicks.to_f / total_queries).round(2) if total_queries > 0)
    row << ((total_clicks.to_f / total_queries / total_queries).round(4) if total_queries > 0)
    
    row << (self.class.mean_ordinality_over_segments(matching_click_segments.map {|segment| [segment.total_events, segment.mean_ordinality]})).round(1)

  end

  def self.mean_ordinality_over_segments(click_ordinality_arrays)
    ordinality_fraction = click_ordinality_arrays.inject({ordinality_total: 0, click_total: 0}) do |sum, click|
      sum[:ordinality_total] += click[0] * click[1]
      sum[:click_total] += click[0]
      sum
    end

    return 0.0 if ordinality_fraction[:click_total] == 0

    ordinality_fraction[:ordinality_total] / ordinality_fraction[:click_total] rescue 0
  end

end 
