describe SearchTermByDimensions do

  describe "report_basename" do

    it "'yesterday' as a start_date or end_date will turn into the appropriate YYYY-MM-DD" do
      report = SearchTermByDimensions.new(start_date: 'yesterday', end_date: 'yesterday')
      yesterday_as_string  = (Date.today - 1).strftime
      expect(report.report_basename).to eq("output_#{yesterday_as_string}_#{yesterday_as_string}.csv")
    end

    it "'today' as a start_date or end_date will turn into the appropriate YYYY-MM-DD" do
      report = SearchTermByDimensions.new(start_date: 'today', end_date: 'today')
      today_as_string  = (Date.today).strftime
      expect(report.report_basename).to eq("output_#{today_as_string}_#{today_as_string}.csv")
    end

    it "accepts YYYY-MM-DD as start_date and end_date" do
      report = SearchTermByDimensions.new(start_date: '1980-09-16', end_date: 'today')
      today_as_string  = (Date.today).strftime
      expect(report.report_basename).to eq("output_1980-09-16_#{today_as_string}.csv")
    end
  end
end
