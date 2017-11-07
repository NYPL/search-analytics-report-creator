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
end 
