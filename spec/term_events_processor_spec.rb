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

    @events_processor = TermEventsProcessor.new(click_segments: clickthrough_segments, query_segments: query_segments, term: 'arbitrary', dimensions: [:searched_repo, :searched_from])
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
     
  end

  describe "data_row_for_values" do

    it "will return an array summarizing data from single matching segment" do
      result_row = @events_processor.data_row_for_values({searched_repo: 'repo3', 'searched_from': 'from3'})
      expect(result_row).to eql(['arbitrary', 'repo3', 'from3', 122, 100, 0.82, 0.0067, 2.0])
    end

    it "will return a single array even if there are mutliple segments matching the specified values" do
      result_row = @events_processor.data_row_for_values({searched_repo: 'repo1', 'searched_from': 'from4'})
      expect(result_row).to eql(['arbitrary', 'repo1', 'from4', 30, 11, 0.37, 0.0122, 3.6])
    end

    it "will return appropriate values if we have clickthrough events but no queries" do
      @events_processor.click_segments << ClickResponse.new(dimensions: {searched_repo: 'repo1', searched_from: 'unwired_form'}, total_events: 5, mean_ordinality: 2.0)
      result_row = @events_processor.data_row_for_values({searched_repo: 'repo1', 'searched_from': 'unwired_form'})
      expect(result_row).to eql(['arbitrary', 'repo1', 'unwired_form', 0, 5, nil, nil, 2.0])
    end

    it "will return appropriate values if we have query events but no clickthroughs" do
      result_row = @events_processor.data_row_for_values({searched_repo: 'repo2', 'searched_from': 'from1'})
      expect(result_row).to eql(['arbitrary', 'repo2', 'from1', 1, 0, 0.00, 0.0000, 0.0])
    end

    it "will return nil if no click or query segments match the specified values" do
      expect(@events_processor.data_row_for_values({searched_repo: 'repo1', 'searched_from': 'from1'})).to be(nil)
    end

  end
  
  describe "process_data_for_dimensions" do

    it "will return output of `data_row_for_values` if no dimensions are specified" do
      report_array = @events_processor.process_data_for_dimensions([], values: {searched_repo: 'repo3', 'searched_from': 'from3'}) 
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

  end

  describe "calculate_aggregates_for_dimension" do
    let(:events_processor) {
      TermEventsProcessor.new(click_segments: [], query_segments: [], term: 'xx', dimensions: [:dim1, :dim2, :dim3])
    }
    
    it "will sum values for a specific dimension" do
      segment_rows = [
        ['xx', 'dim1_a', 'dim2_a', 'dim3_a', 10, 6, 0.33, 0.1111, 10.0],
        ['xx', 'dim1_a', 'dim2_a', 'dim3_b', 20, 4, 0.77, 0.0059, 2.0],
        ['xx', 'dim1_a', 'dim2_a', 'dim3_c', 30, 2, 0.37, 0.0122, 3.6],
      ]
     

      events_processor.calculate_aggregates_for_dimension!(:dim3, {dim1: 'dim1_a', dim2: 'dim2_a'}, segment_rows)
      expect(segment_rows).to eql(
        [
          ['xx', 'dim1_a', 'dim2_a', 'dim3_a', 10, 6, 0.33, 0.1111, 10.0],
          ['xx', 'dim1_a', 'dim2_a', 'dim3_b', 20, 4, 0.77, 0.0059, 2.0],
          ['xx', 'dim1_a', 'dim2_a', 'dim3_c', 30, 2, 0.37, 0.0122, 3.6],
          ['xx', 'dim1_a', 'dim2_a', 'ALL', 60, 12, 0.20, 0.0033, 6.3],
        ]
      )
    end

    it "will sum the next dimension of a partially aggregated data set" do

      segment_rows = [
        ['xx', 'dim1_a', 'dim2_a', 'dim3_a', 10, 6, 0.33, 0.1111, 10.0],
        ['xx', 'dim1_a', 'dim2_a', 'dim3_b', 20, 4, 0.77, 0.0059, 2.0],
        ['xx', 'dim1_a', 'dim2_a', 'dim3_c', 30, 2, 0.37, 0.0122, 3.6],
        ['xx', 'dim1_a', 'dim2_a', 'ALL', 60, 12, 0.20, 0.0033, 6.3],
        ['xx', 'dim1_a', 'dim2_b', 'dim3_a', 20, 7, 0.35, 0.0175, 10.0],
        ['xx', 'dim1_a', 'dim2_b', 'dim3_b', 30, 5, 0.17, 0.0056, 2.0],
        ['xx', 'dim1_a', 'dim2_b', 'dim3_c', 40, 3, 0.08, 0.0019, 3.6],
        ["xx", "dim1_a", "dim2_b", "ALL", 90, 15, 0.17, 0.0019, 6.1],
      ]

      events_processor.calculate_aggregates_for_dimension!(:dim2, {dim1: 'dim1_a'}, segment_rows)
      expect(segment_rows).to eql(
        [
          ['xx', 'dim1_a', 'dim2_a', 'dim3_a', 10, 6, 0.33, 0.1111, 10.0],
          ['xx', 'dim1_a', 'dim2_a', 'dim3_b', 20, 4, 0.77, 0.0059, 2.0],
          ['xx', 'dim1_a', 'dim2_a', 'dim3_c', 30, 2, 0.37, 0.0122, 3.6],
          ['xx', 'dim1_a', 'dim2_a', 'ALL', 60, 12, 0.20, 0.0033, 6.3],
          ['xx', 'dim1_a', 'dim2_b', 'dim3_a', 20, 7, 0.35, 0.0175, 10.0],
          ['xx', 'dim1_a', 'dim2_b', 'dim3_b', 30, 5, 0.17, 0.0056, 2.0],
          ['xx', 'dim1_a', 'dim2_b', 'dim3_c', 40, 3, 0.08, 0.0019, 3.6],
          ["xx", "dim1_a", "dim2_b", "ALL", 90, 15, 0.17, 0.0019, 6.1],
          ["xx", "dim1_a", "ALL", "ALL", 150, 27, 0.18, 0.0012, 6.2],
        ]
      )

    end
    it "will sum the next dimension of a partially aggregated data set" do

      segment_rows = [
          ['xx', 'dim1_a', 'dim2_a', 'dim3_a', 10, 6, 0.33, 0.1111, 10.0],
          ['xx', 'dim1_a', 'dim2_a', 'dim3_b', 20, 4, 0.77, 0.0059, 2.0],
          ['xx', 'dim1_a', 'dim2_a', 'dim3_c', 30, 2, 0.37, 0.0122, 3.6],
          ['xx', 'dim1_a', 'dim2_a', 'ALL', 60, 12, 0.20, 0.0033, 6.3],
          ['xx', 'dim1_a', 'dim2_b', 'dim3_a', 20, 7, 0.35, 0.0175, 10.0],
          ['xx', 'dim1_a', 'dim2_b', 'dim3_b', 30, 5, 0.17, 0.0056, 2.0],
          ['xx', 'dim1_a', 'dim2_b', 'dim3_c', 40, 3, 0.08, 0.0019, 3.6],
          ["xx", "dim1_a", "dim2_b", "ALL", 90, 15, 0.17, 0.0019, 6.1],
          ["xx", "dim1_a", "ALL", "ALL", 150, 27, 0.18, 0.0012, 6.2],
          ['xx', 'dim1_b', 'dim2_a', 'dim3_a', 30, 9, 0.30, 0.0100, 10.0],
          ['xx', 'dim1_b', 'dim2_a', 'dim3_b', 10, 9, 0.90, 0.0900, 2.0],
          ['xx', 'dim1_b', 'dim2_a', 'dim3_c', 20, 9, 0.45, 0.0023, 3.6],
          ['xx', 'dim1_b', 'dim2_a', 'ALL', 60, 27, 0.45, 0.0075, 5.2],
          ['xx', 'dim1_b', 'dim2_b', 'dim3_a', 60, 40, 0.67, 0.0111, 10.0],
          ['xx', 'dim1_b', 'dim2_b', 'dim3_b', 30, 20, 0.67, 0.0222, 2.0],
          ['xx', 'dim1_b', 'dim2_b', 'dim3_c', 10, 5, 0.50, 0.0500, 3.6],
          ["xx", "dim1_b", "dim2_b", "ALL", 100, 65, 0.65, 0.0007, 7.0],
          ["xx", "dim1_b", "ALL", "ALL", 160, 92, 0.58, 0.0036, 6.5],
         ]

      events_processor.calculate_aggregates_for_dimension!(:dim1, {}, segment_rows)
      expect(segment_rows).to eql(
        [
          ['xx', 'dim1_a', 'dim2_a', 'dim3_a', 10, 6, 0.33, 0.1111, 10.0],
          ['xx', 'dim1_a', 'dim2_a', 'dim3_b', 20, 4, 0.77, 0.0059, 2.0],
          ['xx', 'dim1_a', 'dim2_a', 'dim3_c', 30, 2, 0.37, 0.0122, 3.6],
          ['xx', 'dim1_a', 'dim2_a', 'ALL', 60, 12, 0.20, 0.0033, 6.3],
          ['xx', 'dim1_a', 'dim2_b', 'dim3_a', 20, 7, 0.35, 0.0175, 10.0],
          ['xx', 'dim1_a', 'dim2_b', 'dim3_b', 30, 5, 0.17, 0.0056, 2.0],
          ['xx', 'dim1_a', 'dim2_b', 'dim3_c', 40, 3, 0.08, 0.0019, 3.6],
          ["xx", "dim1_a", "dim2_b", "ALL", 90, 15, 0.17, 0.0019, 6.1],
          ["xx", "dim1_a", "ALL", "ALL", 150, 27, 0.18, 0.0012, 6.2],
          ['xx', 'dim1_b', 'dim2_a', 'dim3_a', 30, 9, 0.30, 0.0100, 10.0],
          ['xx', 'dim1_b', 'dim2_a', 'dim3_b', 10, 9, 0.90, 0.0900, 2.0],
          ['xx', 'dim1_b', 'dim2_a', 'dim3_c', 20, 9, 0.45, 0.0023, 3.6],
          ['xx', 'dim1_b', 'dim2_a', 'ALL', 60, 27, 0.45, 0.0075, 5.2],
          ['xx', 'dim1_b', 'dim2_b', 'dim3_a', 60, 40, 0.67, 0.0111, 10.0],
          ['xx', 'dim1_b', 'dim2_b', 'dim3_b', 30, 20, 0.67, 0.0222, 2.0],
          ['xx', 'dim1_b', 'dim2_b', 'dim3_c', 10, 5, 0.50, 0.0500, 3.6],
          ["xx", "dim1_b", "dim2_b", "ALL", 100, 65, 0.65, 0.0007, 7.0],
          ["xx", "dim1_b", "ALL", "ALL", 160, 92, 0.58, 0.0036, 6.5],
          ["xx", "ALL", "ALL", "ALL", 310, 119, 0.38, 0.0012, 6.4],
         ]
      )

    end
 
  end
end
