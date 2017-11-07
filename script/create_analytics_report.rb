require 'optparse'
require File.join(File.absolute_path(__dir__), '..', 'lib', 'report_runner')

options = {}
OptionParser.new do |parser|
  parser.banner = 'USAGE: ruby ./script/create_analytics_reports.rb [options]'

  parser.on('-i', '--id ID', 'Google Analytics profile id in the form ga:XXXX where XXXX is the Analytics view (profile) ID') do |id|
    options[:ga_profile_id] = id
  end

  parser.on('-a', '--auth-file path/to/auth/file.json', 'path to file that contains google API account info and private_key') do |file_path|
    options[:auth_file] = file_path
  end

  parser.on('-s', '--start-date STARTDATE', 'Start date of the report. Formatting can be found here: https://developers.google.com/analytics/devguides/reporting/core/v3/reference#startDate') do |start_date|
    options[:start_date] = start_date
  end

  parser.on('-e', '--end-date ENDDATE', 'End date of the report. Formatting can be found here: https://developers.google.com/analytics/devguides/reporting/core/v3/reference#endDate') do |end_date|
    options[:end_date] = end_date
  end

  parser.on('-o', '--output OUTPUT', 'output can be: /path/to/a/dir/ or "google-sheets"') do |specified_output|
    options[:output] = specified_output
  end

  parser.on('-g', '--google-parent-id PARENTFOLDERID', 'id of google drive folder to put report in') do |google_parent_id|
    options[:google_parent_id] = google_parent_id
  end

  parser.on_tail('-h', '--help', 'Prints this help') do
    puts parser
    exit
  end
end.parse!

report_runner = ReportRunner.new(options)

if !report_runner.valid?
  puts "\nError running report, errors: #{report_runner.errors.join(', ')}\n\n"
  exit 1
else
  report_runner.generate_report
end
