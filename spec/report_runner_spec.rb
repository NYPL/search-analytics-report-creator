require File.join(__dir__, '..', 'config', 'app')

describe ReportRunner do
  describe "validation" do
    it "will have an error without a google_id" do
      report_runner = ReportRunner.new
      expect(report_runner).to_not be_valid
      expect(report_runner.errors).to include("is missing ga_profile_id")
    end

    it "will have an error without a start_date" do
      report_runner = ReportRunner.new
      expect(report_runner).to_not be_valid
      expect(report_runner.errors).to include("is missing start_date")
    end

    it "will have an error without a end_date" do
      report_runner = ReportRunner.new
      expect(report_runner).to_not be_valid
      expect(report_runner.errors).to include("is missing end_date")
    end

    it "will have an error without auth_file" do
      report_runner = ReportRunner.new
      expect(report_runner).to_not be_valid
      expect(report_runner.errors).to include("is missing auth_file")
    end

    it "will have an error if given 'google-sheets' as an output but no google_parent_id" do
      report_runner = ReportRunner.new(output: 'google-sheets')
      report_runner.valid?
      expect(report_runner).to_not be_valid
      
      expect(report_runner.errors).to include("requires a google_parent_id for google-sheets output")

      report_runner.google_parent_id = "nowihaveavalue"
      expect(report_runner).to_not be_valid
      expect(report_runner.errors).to_not include("requires a google_parent_id for google-sheets output")
    end

    let(:valid_options) {{
      ga_profile_id: 'dummyid',
      start_date: 'today',
      end_date: 'today',
      output: '/dev/null',
      auth_file: './auth.json',
      google_parent_id: 'dummyparentid',
    }}

    it "will not require any dimensions" do
      report_runner = ReportRunner.new(valid_options)
      expect(report_runner.valid?).to be(true)

      expect(report_runner.errors).to eql([])
    end

    it "will have an error if specified dimenion is not implemented in config/app.rb" do
      CONFIG[:implemented_dimensions].clear

      invalid_options = valid_options.dup
      invalid_options[:dimensions] = ['unimplemented_dimension']
      report_runner = ReportRunner.new(invalid_options)

      expect(report_runner.valid?).to be(false)
      expect(report_runner.errors).to eql(['\'unimplemented_dimension\' is not implemented in configuration file config/app.rb'])
    end

    it "will not have an error if specified dimension is implemented in config/app.rb" do
      CONFIG[:implemented_dimensions].clear
      CONFIG[:implemented_dimensions]['valid_dimension'] = {}

      valid_options[:dimensions] = ['valid_dimension']
      report_runner = ReportRunner.new(valid_options)

      expect(report_runner.valid?).to be(true)
    end

    it "will have an error if valid and invalid dimenions are included" do
      CONFIG[:implemented_dimensions].clear
      CONFIG[:implemented_dimensions]['valid_dimension'] = {}

      options = valid_options.dup
      options[:dimensions] = ['valid_dimension', 'unimplemented_dimension']

      report_runner_1 = ReportRunner.new(options)
      expect(report_runner_1.valid?).to be(false)
      expect(report_runner_1.errors).to eql(['\'unimplemented_dimension\' is not implemented in configuration file config/app.rb'])

      options[:dimensions] = options[:dimensions].reverse
      report_runner_2 = ReportRunner.new(options)
      expect(report_runner_2.valid?).to be(false)
      expect(report_runner_2.errors).to eql(['\'unimplemented_dimension\' is not implemented in configuration file config/app.rb'])
    end

  end
end
