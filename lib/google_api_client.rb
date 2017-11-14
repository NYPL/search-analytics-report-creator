require 'google/apis/drive_v3'
require 'googleauth'
require 'google/apis/analytics_v3'
require 'google/apis/sheets_v4'

class GoogleApiClient
  def initialize(options = {auth_file: nil})
    @auth_file = options[:auth_file]

    raise "missing auth_file" if @auth_file.nil?
  end

  def drive_file
    Google::Apis::DriveV3::File
  end

  def analytics_client
    client = Google::Apis::AnalyticsV3::AnalyticsService.new
    client.authorization = auth_analytics
    client
  end

  def drive_client
    client = Google::Apis::DriveV3::DriveService.new
    client.authorization = auth_drive
    client
  end

  def sheets_client
    client = Google::Apis::SheetsV4::SheetsService.new
    client.authorization = auth_drive
    client
  end

  def auth_analytics
    auth(scopes: ['https://www.googleapis.com/auth/analytics.readonly'])
  end

  def auth_drive
    auth(scopes: ['https://www.googleapis.com/auth/drive.file'])
  end

private

  def auth(scopes: [])
    Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: File.open(@auth_file, 'r'), scope: scopes)
  end

end