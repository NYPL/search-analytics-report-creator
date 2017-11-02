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

    it "will have an error without auth_file" do
      report_runner = ReportRunner.new
      expect(report_runner).to_not be_valid
      expect(report_runner.errors).to include("is missing output")
    end

  end
end
