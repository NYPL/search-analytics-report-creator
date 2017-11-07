require 'google/apis/drive_v3'
require 'googleauth'
require 'google/apis/analytics_v3'
require 'date'

class SearchTermByRepoAndSearchedFrom

  def initialize(options = {})
    @auth_file     = options[:auth_file]
    @ga_profile_id = options[:ga_profile_id]
    @start_date    = options[:start_date]
    @end_date      = options[:end_date]
    @output        = options[:output]
    @google_parent_id = options[:google_parent_id]
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
    dir = (@output == "google-sheets") ? File.join(File.absolute_path('.'), self.report_basename) : File.join(File.absolute_path(@output), self.report_basename)
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

    CSV.open(report_output_path, 'wb') do |csv|
      headers = ['Search Term', 'Searched Repo', 'Searched From', 'Total Searches', 'Total Clicks', 'CTR', 'Mean Ordinality']
      csv << headers

      all_query_terms = queries.map(&:search_term).uniq
      all_query_terms.each do |query_term|
        all_clicks_for_this = clicks.find_all { |click| click.search_term == query_term }
        all_clicks_for_this.group_by(&:searched_repo).each do |searched_repo, click_events|
          click_events.each do |click_event|
            row = []
            row << query_term
            row << click_event.searched_repo
            row << click_event.searched_from

            matching_query_event =  queries.find { |query| query.search_term == query_term && query.searched_from == click_event.searched_from && query.searched_repo == click_event.searched_repo }
            row << matching_query_event.total_events
            row << click_event.total_events
            row << '%.2f' % ((click_event.total_events.to_f / matching_query_event.total_events) * 100)
            row << '%.2f' % click_event.mean_ordinality
            csv << row
          end

          sum_for_searched_repo_row = []
          sum_for_searched_repo_row << query_term
          sum_for_searched_repo_row << searched_repo
          sum_for_searched_repo_row << "ALL"


          all_queries_for_this = queries.find_all {|query| query.search_term == query_term && query.searched_repo == searched_repo}

          # Total searches
          total_searches = all_queries_for_this.inject(0) {|sum, query| sum + query.total_events }
          sum_for_searched_repo_row << total_searches

          # Total clicks
          total_clicks = click_events.inject(0) {|sum, click| sum + click.total_events }
          sum_for_searched_repo_row << total_clicks

          # CTR
          sum_for_searched_repo_row << '%.2f' % ((total_clicks.to_f / total_searches) * 100)

          # Mean Ordinality
          sum_for_searched_repo_row << ('%.2f' % (mean_ordinality_over_segments(click_events)))

          csv << sum_for_searched_repo_row
        end
      end
    end

    if @output == "google-sheets"
      upload_to_drive
    end

  end

  def upload_to_drive
    drive = Google::Apis::DriveV3::DriveService.new
    scopes = ['https://www.googleapis.com/auth/drive.file']
    auth = Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: File.open(@auth_file, 'r'), scope: scopes)

    drive.authorization = auth
    # Upload a file
    metadata = Google::Apis::DriveV3::File.new(name: self.report_basename, mime_type: 'application/vnd.google-apps.spreadsheet')
    file = drive.create_file(metadata, upload_source: self.report_output_path, content_type: 'text/csv', supports_team_drives: true)
    drive.update_file(file.id, add_parents: @google_parent_id)
  end

  def mean_ordinality_over_segments(clickthrough_segments)
      ordinality_fraction = clickthrough_segments.inject({ordinality_total: 0, click_total: 0}) do |sum, click|
        sum[:ordinality_total] += click.mean_ordinality * click.total_events
        sum[:click_total] += click.total_events
        sum
      end

      ordinality_fraction[:ordinality_total] / ordinality_fraction[:click_total]
  end
end
