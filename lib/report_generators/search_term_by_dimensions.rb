require 'google/apis/drive_v3'
require 'googleauth'
require 'google/apis/analytics_v3'
require 'google/apis/sheets_v4'
require 'date'

require File.join(File.dirname(__FILE__), '..', '..', 'config', 'app')

class SearchTermByDimensions
  attr_accessor :queries, :clicks, :dimensions

  def initialize(options = {})
    @auth_file     = options[:auth_file]
    @ga_profile_id = options[:ga_profile_id]
    @start_date    = options[:start_date]
    @end_date      = options[:end_date]
    @output        = options[:output]
    @google_parent_id = options[:google_parent_id]
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

  def auth_analytics
    auth(scopes: ['https://www.googleapis.com/auth/analytics.readonly'])
  end

  def auth_drive
    auth(scopes: ['https://www.googleapis.com/auth/drive.file'])
  end

  def auth(scopes: [])
    Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: File.open(@auth_file, 'r'), scope: scopes)
  end

  def get_events()
    stats = Google::Apis::AnalyticsV3::AnalyticsService.new
    stats.authorization = auth_analytics

    query_response = stats.get_ga_data(@ga_profile_id, @start_date, @end_date, 'ga:totalEvents,ga:uniqueEvents', dimensions: 'ga:eventLabel,ga:eventAction,ga:dimension1,ga:dimension2', max_results: 10000, filters: "ga:eventCategory==Search;ga:eventAction==QuerySent", sort: "-ga:totalEvents")
    click_response = stats.get_ga_data(@ga_profile_id, @start_date, @end_date, 'ga:totalEvents,ga:uniqueEvents,ga:avgEventValue', dimensions: 'ga:eventLabel,ga:eventAction,ga:dimension1,ga:dimension2', max_results: 10000, filters: "ga:eventCategory==Search;ga:eventAction==Clickthrough", sort: "ga:eventLabel")

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
  end

  def process_data_for_term(term)
    events_processor = TermEventsProcessor.new(term: term, query_segments: query_events_for_term(term), click_segments: click_events_for_term(term))
    events_processor.process
  end

  def click_events_for_term(term)
    clicks.find_all { |click| click.search_term == term }
  end

  def query_events_for_term(term)
    queries.find_all { |query| query.search_term == term }
  end

  def generate_report!

    get_events
    
    all_query_terms = queries.map(&:search_term).uniq
    all_results = all_query_terms.inject([]) do |running_results, query_term|
     
      running_results.concat(process_data_for_term(query_term))

    end

    CSV.open(report_output_path, 'wb') do |csv|
      headers = ['search term', 'row number', 'searched repo', 'searched from', 'total searches', 'total clicks', 'ctr', 'wctr', 'mean ordinality']
      csv << headers
      all_results.each { |row| csv << row }
    end

    if @output == "google-sheets"
      upload_to_drive
    end

  end

  def upload_to_drive
    drive = Google::Apis::DriveV3::DriveService.new
    drive.authorization = auth_drive

    # upload a file
    metadata = Google::Apis::DriveV3::File.new(name: self.report_basename, mime_type: 'application/vnd.google-apps.spreadsheet')
    file = drive.create_file(metadata, upload_source: self.report_output_path, content_type: 'text/csv', supports_team_drives: true)
    drive.update_file(file.id, add_parents: @google_parent_id)

    filter_spreadsheet(file)
  end

  def filter_spreadsheet(file)
    sheets = Google::Apis::SheetsV4::SheetsService.new
    sheets.authorization = auth_drive
    
    spreadsheet = sheets.get_spreadsheet(file.id)

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
    
    sheets.batch_update_spreadsheet(file.id, requests, {})
  end

end

class TermEventsProcessor
  attr_accessor :term, :query_segments, :click_segments

  @@dimensions = CONFIG[:dimensions]

  def initialize(term:, query_segments:, click_segments:)

    @term = term
    @query_segments = query_segments
    @click_segments = click_segments

  end

  def process
    process_data_for_dimensions(@@dimensions)
  end

  def process_data_for_dimensions(dimensions, values: {})
    return [data_row_for_values(values)] if dimensions.empty?

    this_dimension = dimensions.shift

    dimension_values = get_values(this_dimension)

    event_rows = dimension_values.inject([]) do |rows, value|

      values[this_dimension] = value
      rows.concat(process_data_for_dimensions(dimensions.dup, values: values).compact)
      
      rows

    end

    # calculate_aggregates_for_dimension(event_rows, this_dimension)
    event_rows

  end

  def get_values(dimension)
    (click_segments.map(&dimension) + query_segments.map(&dimension)).uniq.sort
  end

  def segments_for_values(segment_type, values)
    # For each event segment
      self.send(segment_type).find_all do |segment|
      # return all segments which match the appropriate values
      values.each_pair.all? do |dimension, value|
        segment.send(dimension) == value
      end
    end
  end

  def data_row_for_values(values)
    matching_query_segments = segments_for_values(:query_segments, values)
    matching_click_segments = segments_for_values(:click_segments, values)

    return nil if matching_query_segments.empty? and matching_click_segments.empty?

    row = []
    row << term

    row.concat @@dimensions.map { |dimension| values[dimension] }
    
    total_queries = matching_query_segments.inject(0) { |sum, segment| sum += segment.total_events }
    row << total_queries

    total_clicks = matching_click_segments.inject(0) { |sum, segment| sum += segment.total_events }
    row << total_clicks

    # Will enter nil if total_queries is 0
    row << ((total_clicks.to_f / total_queries).round(2) if total_queries > 0)
    row << ((total_clicks.to_f / total_queries / total_queries).round(4) if total_queries > 0)
    
    row << (self.class.mean_ordinality_over_segments(matching_click_segments)).round(1)

  end

  def self.mean_ordinality_over_segments(clickthrough_segments)
    ordinality_fraction = clickthrough_segments.inject({ordinality_total: 0, click_total: 0}) do |sum, click|
      sum[:ordinality_total] += click.mean_ordinality * click.total_events
      sum[:click_total] += click.total_events
      sum
    end

    ordinality_fraction[:ordinality_total] / ordinality_fraction[:click_total] rescue 0
  end

end 
