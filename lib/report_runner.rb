require 'csv'
Dir[File.join(File.dirname(__FILE__), 'report_generators', '*.rb')].each {|file| require file }
Dir[File.join(File.dirname(__FILE__), '*.rb')].each {|file| require file }

class ReportRunner
  attr_reader :dimensions, :errors
  attr_accessor :google_parent_id

  def initialize(options = {})
    @errors = []
    @ga_profile_id = options[:ga_profile_id]
    @start_date    = options[:start_date]
    @end_date      = options[:end_date]
    @auth_file     = options[:auth_file]
    @output        = options[:output]
    @google_parent_id = options[:google_parent_id]
    @dimensions = options[:dimensions] || []
  end

  def valid?
    @errors = []
    has_required_attribute?(:@ga_profile_id)
    has_required_attribute?(:@start_date)
    has_required_attribute?(:@end_date)
    has_required_attribute?(:@output)
    has_required_attribute?(:@auth_file)
    check_google_parent_id?
    dimensions_valid?

    @errors.empty?
  end

  def generate_report
    report_generator = SearchTermByDimensions.new({
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

  def check_google_parent_id?
    if @output == "google-sheets" && @google_parent_id.nil?
      @errors << "requires a google_parent_id for google-sheets output"
      return false
    end

    return true
  end

  def has_required_attribute?(attr)
    if instance_variable_get(attr).nil?
      @errors << "is missing #{attr.to_s[1..-1]}"
      return false
    else
      return true
    end
  end

  def dimensions_valid?
    dimensions.each do |dimension|
      unless CONFIG[:implemented_dimensions].has_key?(dimension)
        @errors << "'#{dimension}' is not implemented in configuration file config/app.rb"
      end
    end
  end
end
