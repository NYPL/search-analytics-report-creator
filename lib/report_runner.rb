require 'csv'
Dir[File.join(File.dirname(__FILE__), 'report_generators', '*.rb')].each {|file| require file }
Dir[File.join(File.dirname(__FILE__), '*.rb')].each {|file| require file }

class ReportRunner
  attr_reader :errors
  attr_accessor :google_parent_id

  def initialize(options = {})
    @errors = []
    @ga_profile_id = options[:ga_profile_id]
    @start_date    = options[:start_date]
    @end_date      = options[:end_date]
    @auth_file     = options[:auth_file]
    @output        = options[:output]
    @google_parent_id = options[:google_parent_id]
  end

  def valid?
    @errors = []
    checks = [
      has_required_attribute?(:@ga_profile_id),
      has_required_attribute?(:@start_date),
      has_required_attribute?(:@end_date),
      has_required_attribute?(:@output),
      has_required_attribute?(:@auth_file),
      has_google_parent_id?
    ]

    @errors.empty?
  end

  def generate_report
    report_generator = SearchTermByRepoAndSearchedFrom.new({
      auth_file: @auth_file,
      ga_profile_id: @ga_profile_id ,
      start_date: @start_date,
      end_date: @end_date,
      output: @output,
      google_parent_id: @google_parent_id
    })

    report_generator.generate_report!
  end

private

  def has_google_parent_id?
    if @output == "google-sheets"
      if !@google_parent_id.nil?
        return true
      else
        @errors << "requires a drive_parent_id for google-sheets output"
        return false
      end
    else
      true
    end
  end

  def has_required_attribute?(attr)
    if instance_variable_get(attr).nil?
      @errors << "is missing #{attr.to_s[1..-1]}"
      return false
    else
      return true
    end
  end
end
