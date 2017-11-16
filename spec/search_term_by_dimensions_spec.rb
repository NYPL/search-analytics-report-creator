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

   describe "results_for_terms" do
     report = SearchTermByDimensions.new
    report.queries = [
      QueryResponse.new(search_term: 'Boney M', searched_repo: 'Encore', searched_from: 'HeaderSearch', total_events: 3),
      QueryResponse.new(search_term: 'Boney M', searched_repo: 'DrupalSearch', searched_from: 'HeaderSearch', total_events: 2),
      QueryResponse.new(search_term: 'Boney M', searched_repo: 'Encore', searched_from: 'EncoreSearchForm', total_events: 5),
      QueryResponse.new(search_term: 'Boney M', searched_repo: 'DrupalSearch', searched_from: 'DrupalSearchForm', total_events: 1),
      QueryResponse.new(search_term: 'Best Books 2017', searched_repo: 'DrupalSearch', searched_from: 'DrupalSearchForm', total_events: 43),
      QueryResponse.new(search_term: 'Best Books 2017', searched_repo: 'Encore', searched_from: 'HeaderSearch', total_events: 6),
      QueryResponse.new(search_term: 'Best Books 2017', searched_repo: 'Encore', searched_from: 'EncoreSearchForm', total_events: 2),
      QueryResponse.new(search_term: 'Best Books 2017', searched_repo: 'DrupalSearch', searched_from: 'HeaderSearch', total_events: 33),
    ]
    report.clicks = [
      ClickResponse.new(search_term: 'Boney M', searched_repo: 'Encore', searched_from: 'HeaderSearch', total_events: 2, mean_ordinality: 2.0),
      ClickResponse.new(search_term: 'Boney M', searched_repo: 'Encore', searched_from: 'EncoreSearchForm', total_events: 3, mean_ordinality: 4.1),
      ClickResponse.new(search_term: 'Best Books 2017', searched_repo: 'DrupalSearch', searched_from: 'DrupalSearchForm', total_events: 37, mean_ordinality: 3.4),
      ClickResponse.new(search_term: 'Best Books 2017', searched_repo: 'Encore', searched_from: 'HeaderSearch', total_events: 1, mean_ordinality: 4.0),
      ClickResponse.new(search_term: 'Best Books 2017', searched_repo: 'DrupalSearch', searched_from: 'HeaderSearch', total_events: 26, mean_ordinality: 1.8),
      ClickResponse.new(search_term: 'Anchorage', searched_repo: 'DrupalSearch', searched_from: 'HeaderSearch', total_events: 1, mean_ordinality: 6.0),
    ]

    it "will produce an array of results for each permutation " do
      results = report.results_for_terms(['Anchorage', 'Best Books 2017', 'Boney M'])
      
      # These are sorted alphabetically but will be in order of queries once we're doing aggregates.
      expect(results).to eql([
        ['Anchorage', 'DrupalSearch', 'HeaderSearch', 0, 1, nil, nil, 6.0],
        ['Best Books 2017', 'DrupalSearch', 'DrupalSearchForm', 43, 37, 0.86, 0.0200, 3.4],
        ['Best Books 2017', 'DrupalSearch', 'HeaderSearch', 33, 26, 0.79, 0.0239, 1.8],
        ['Best Books 2017', 'Encore', 'EncoreSearchForm', 2, 0, 0.0, 0.000, 0.0],
        ['Best Books 2017', 'Encore', 'HeaderSearch', 6, 1, 0.17, 0.0278, 4.0],
        ['Boney M', 'DrupalSearch', 'DrupalSearchForm', 1, 0, 0.0, 0.000, 0.0],
        ['Boney M', 'DrupalSearch', 'HeaderSearch', 2, 0, 0.0, 0.000, 0.0],
        ['Boney M', 'Encore', 'EncoreSearchForm', 5, 3, 0.6, 0.1200, 4.1],
        ['Boney M', 'Encore', 'HeaderSearch', 3, 2, 0.67, 0.2222, 2.0],
      ])
    end

  end

end
