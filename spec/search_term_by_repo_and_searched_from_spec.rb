describe SearchTermByRepoAndSearchedFrom do
  describe "ordinality" do

    it "will calculate mean ordinality across multiple clicks segmented by repo" do
      report = SearchTermByRepoAndSearchedFrom.new
      clickthrough_segments = [
        instance_double("ClickResponse", :searched_repo => 'repo1', :total_events => 1, :mean_ordinality => 10.0),
        instance_double("ClickResponse", :searched_repo => 'repo2', :total_events => 10, :mean_ordinality => 3.0),
        instance_double("ClickResponse", :searched_repo => 'repo3', :total_events => 100, :mean_ordinality => 2.0),
      ]

      # there are 111 total events, and the total sum of all the ordinalities is equal to 1*10.0 + 10*3.0 + 100*2.0
      expect(report.mean_ordinality_over_segments(clickthrough_segments)).to equal(240.0/111)
    end
  end

  describe "report_basename" do

    it "'yesterday' as a start_date or end_date will turn into the appropriate YYYY-MM-DD" do
      report = SearchTermByRepoAndSearchedFrom.new(start_date: 'yesterday', end_date: 'yesterday')
      yesterday_as_string  = (Date.today - 1).strftime
      expect(report.report_basename).to eq("output_#{yesterday_as_string}_#{yesterday_as_string}.csv")
    end

    it "'today' as a start_date or end_date will turn into the appropriate YYYY-MM-DD" do
      report = SearchTermByRepoAndSearchedFrom.new(start_date: 'today', end_date: 'today')
      today_as_string  = (Date.today).strftime
      expect(report.report_basename).to eq("output_#{today_as_string}_#{today_as_string}.csv")
    end

    it "accepts YYYY-MM-DD as start_date and end_date" do
      report = SearchTermByRepoAndSearchedFrom.new(start_date: '1980-09-16', end_date: 'today')
      today_as_string  = (Date.today).strftime
      expect(report.report_basename).to eq("output_1980-09-16_#{today_as_string}.csv")
    end
  end
end
