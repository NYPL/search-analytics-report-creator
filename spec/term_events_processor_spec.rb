require './lib/report_generators/search_term_by_dimensions.rb'

describe TermEventsProcessor do

  before(:example) do
    clickthrough_segments = [
      ClickResponse.new(dimensions: {searched_repo: 'repo1', searched_from: 'from4', click_target: 'targetZ'}, total_events: 1, mean_ordinality: 10.0),
      ClickResponse.new(dimensions: {searched_repo: 'repo1', searched_from: 'from4', click_target: 'targetA'}, total_events: 10, mean_ordinality: 3.0),
      ClickResponse.new(dimensions: {searched_repo: 'repo1', searched_from: 'from3', click_target: 'targetH'}, total_events: 100, mean_ordinality: 2.0),
      ClickResponse.new(dimensions: {searched_repo: 'repo1', searched_from: 'from2', click_target: 'targetZ'}, total_events: 1, mean_ordinality: 10.0),
      ClickResponse.new(dimensions: {searched_repo: 'repo3', searched_from: 'from3', click_target: 'targetH'}, total_events: 100, mean_ordinality: 2.0),
    ]

    query_segments = [
      QueryResponse.new(dimensions: {searched_repo: 'repo1', searched_from: 'from2'}, total_events: 3),
      QueryResponse.new(dimensions: {searched_repo: 'repo1', searched_from: 'from3'}, total_events: 130),
      QueryResponse.new(dimensions: {searched_repo: 'repo1', searched_from: 'from4'}, total_events: 30),
      QueryResponse.new(dimensions: {searched_repo: 'repo2', searched_from: 'from1'}, total_events: 1),
      QueryResponse.new(dimensions: {searched_repo: 'repo3', searched_from: 'from3'}, total_events: 122),
    ]

    query_dimensions = [:searched_repo, :searched_from]
    @events_processor = TermEventsProcessor.new(click_segments: clickthrough_segments, query_segments: query_segments, term: 'arbitrary', dimensions: query_dimensions, query_sent_dimensions: query_dimensions)
    @events_processor_with_click_target = TermEventsProcessor.new(click_segments: clickthrough_segments, query_segments: query_segments, term: 'arbitrary', dimensions: [:searched_repo, :searched_from, :click_target], query_sent_dimensions: query_dimensions)
  end

  describe "ordinality" do
    it "will calculate mean ordinality across multiple clicks segmented by repo" do
      click_ordinalities = @events_processor.click_segments[0..2].map {|segment| [segment.total_events, segment.mean_ordinality]}
      expect(TermEventsProcessor.mean_ordinality_over_segments(click_ordinalities)).to eql(240.0/111)
    end
    it "will return same average ordinality if one segment is given" do
      click_ordinalities = @events_processor.click_segments[1..1].map {|segment| [segment.total_events, segment.mean_ordinality]}
      expect(TermEventsProcessor.mean_ordinality_over_segments(click_ordinalities)).to eql(3.0)
    end
  end

  describe "get_values" do
    it "will return a list of values for a given dimension" do
      expect(@events_processor.get_values(:searched_repo)).to eql(["repo1", "repo2", "repo3"])
    end

    it "will return a sorted list" do
      expect(@events_processor.get_values(:searched_from)).to eql(["from1", "from2", "from3", "from4"])
    end

  end

  describe "segments_for_values" do
    it "will return all click_segments matching a given single dimension value" do
      expect(@events_processor.segments_for_values(:click_segments, {searched_repo: 'repo1'})).to eql(@events_processor.click_segments[0..3])
    end
    it "will return all click_segments matching multiple dimension values" do
      expect(@events_processor.segments_for_values(:click_segments, {searched_repo: 'repo1', searched_from: 'from4'})).to eql(@events_processor.click_segments[0..1])
    end
    it "will return empty array if no segments matched" do
      expect(@events_processor.segments_for_values(:click_segments, {searched_repo: 'repo1', click_target: 'targetZ', searched_from: 'Unknown'})).to eql([])
    end
    it "will also work for query_segments" do
      expect(@events_processor.segments_for_values(:query_segments, {searched_repo: 'repo3', searched_from: 'from3'})).to eql(@events_processor.query_segments[4..4])
    end
    it "query_segments with dimensions not relevant to QuerySent no events will be returned" do
      expect(@events_processor.segments_for_values(:query_segments, {searched_repo: 'repo3', searched_from: 'from3', click_target: 'targetZ'})).to eql([]) 
    end
  end

  describe "data_row_for_values" do
    it "will return an array summarizing data from single matching segment" do
      result_row = @events_processor.data_row_for_values({searched_repo: 'repo3', searched_from: 'from3'})
      expect(result_row).to eql(['arbitrary', 'repo3', 'from3', 122, 100, 0.82, 0.0067, 2.0])
    end

    it "will return a single array even if there are mutliple segments matching the specified values" do
      result_row = @events_processor.data_row_for_values({searched_repo: 'repo1', searched_from: 'from4'})
      expect(result_row).to eql(['arbitrary', 'repo1', 'from4', 30, 11, 0.37, 0.0122, 3.6])
    end

    it "will return appropriate values if we have clickthrough events but no queries" do
      @events_processor.click_segments << ClickResponse.new(dimensions: {searched_repo: 'repo1', searched_from: 'unwired_form'}, total_events: 5, mean_ordinality: 2.0)
      result_row = @events_processor.data_row_for_values({searched_repo: 'repo1', searched_from: 'unwired_form'})
      expect(result_row).to eql(['arbitrary', 'repo1', 'unwired_form', 0, 5, nil, nil, 2.0])
    end

    it "will return appropriate values if we have query events but no clickthroughs" do
      result_row = @events_processor.data_row_for_values({searched_repo: 'repo2', searched_from: 'from1'})
      expect(result_row).to eql(['arbitrary', 'repo2', 'from1', 1, 0, 0.00, 0.0000, 0.0])
    end

    it "will return nil if no click or query segments match the specified values" do
      expect(@events_processor.data_row_for_values({searched_repo: 'repo1', searched_from: 'from1'})).to be(nil)
    end

    it "will return no query-sent data when clickthrough-only dimensions are included" do
      expect(@events_processor_with_click_target.data_row_for_values({searched_repo: 'repo1', searched_from: 'from4', click_target: 'targetA'})).to eql(['arbitrary', 'repo1', 'from4', 'targetA', nil, 10, nil, nil, 3.0])
    end

    it "will aggregate results when a dimension value of 'ALL' is passed in" do
      expect(@events_processor.data_row_for_values({searched_repo: 'repo1', searched_from: 'ALL'})).to eql(['arbitrary', 'repo1', 'ALL', 163, 112, 0.69, 0.0042, 2.2])
    end

    it "will aggregate over a clickthrough-only dimension if value of 'ALL' is passed in" do
      expect(@events_processor_with_click_target.data_row_for_values({searched_repo: 'repo1', searched_from: 'from4', click_target: 'ALL'})).to eql(['arbitrary', 'repo1', 'from4', 'ALL', 30, 11, 0.37, 0.0122, 3.6])
    end

    it "will return no query-sent data when clickthrough-only dimensions are included even if aggregating" do
      expect(@events_processor_with_click_target.data_row_for_values({searched_repo: 'repo1', searched_from: 'ALL', click_target: 'targetZ'})).to eql(['arbitrary', 'repo1', 'ALL', 'targetZ', nil, 2, nil, nil, 10.0])
    end

    it "can aggregate on higher dimensions (though nobody should wanna do this)" do
      expect(@events_processor.data_row_for_values({searched_repo: 'ALL', searched_from: 'from3'})).to eql(['arbitrary', 'ALL', 'from3', 252, 200, 0.79, 0.0031, 2.0])
    end

  end
  
  describe "process_data_for_dimensions" do

    it "will return output of `data_row_for_values` if no dimensions are specified" do
      report_array = @events_processor.process_data_for_dimensions([], values: {searched_repo: 'repo3', searched_from: 'from3'}) 
      expect(report_array).to eql([['arbitrary', 'repo3', 'from3', 122, 100, 0.82, 0.0067, 2.0]])
    end

    it "will return rows for each dimension permutation limited by the selected values" do
      report_array = @events_processor.process_data_for_dimensions([:searched_from], values: {searched_repo: 'repo1'})
      expect(report_array).to eql([
        ['arbitrary', 'repo1', 'from2', 3, 1, 0.33, 0.1111, 10.0],
        ['arbitrary', 'repo1', 'from3', 130, 100, 0.77, 0.0059, 2.0],
        ['arbitrary', 'repo1', 'from4', 30, 11, 0.37, 0.0122, 3.6],
        ['arbitrary', 'repo1', 'ALL', 163, 112, 0.69, 0.0042, 2.2],
      ])
    end

    it "will return rows for each dimension permutation when given no values" do
      report_array = @events_processor.process_data_for_dimensions([:searched_repo, :searched_from])
      expect(report_array).to eql([
        ['arbitrary', 'repo1', 'from2', 3, 1, 0.33, 0.1111, 10.0],
        ['arbitrary', 'repo1', 'from3', 130, 100, 0.77, 0.0059, 2.0],
        ['arbitrary', 'repo1', 'from4', 30, 11, 0.37, 0.0122, 3.6],
        ['arbitrary', 'repo1', 'ALL', 163, 112, 0.69, 0.0042, 2.2],
        ['arbitrary', 'repo2', 'from1', 1, 0, 0.00, 0.0000, 0.0],
        ['arbitrary', 'repo2', 'ALL', 1, 0, 0.00, 0.0000, 0.0],
        ['arbitrary', 'repo3', 'from3', 122, 100, 0.82, 0.0067, 2.0],
        ['arbitrary', 'repo3', 'ALL', 122, 100, 0.82, 0.0067, 2.0],
        ['arbitrary', 'ALL', 'ALL', 286, 212, 0.74, 0.0026, 2.1],
      ])
    end

    it "can handle dimensions which are specific for clickthroughs" do
      report_array = @events_processor_with_click_target.process_data_for_dimensions([:click_target], values: {searched_repo: 'repo2', searched_from: 'from1'})
      expect(report_array).to eql([['arbitrary', 'repo2', 'from1', 'ALL', 1, 0, 0.00, 0.0000, 0.0]])
    end

    it "will report on queries where there are no clicks" do
      query_segments = [
        QueryResponse.new(dimensions: {searched_repo: 'repo1', searched_from: 'from2'}, total_events: 3),
      ]
      @events_processor = TermEventsProcessor.new(click_segments: [], query_segments: query_segments, term: 'arbitrary', dimensions: [:searched_repo, :searched_from, :click_target], query_sent_dimensions: [:searched_repo, :searched_from])

      expect(@events_processor.process_data_for_dimensions([:click_target], values: {searched_repo: 'repo1', searched_from: 'from2'})).to eql([['arbitrary', 'repo1', 'from2', 'ALL', 3, 0, 0.00, 0.0000, 0.0]])

    end
  end

end
