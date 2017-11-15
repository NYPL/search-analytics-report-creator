require './lib/report_generators/search_term_by_dimensions.rb'

describe TermEventsProcessor do

  before(:example) do
    clickthrough_segments = [
      instance_double("ClickResponse", searched_repo: 'repo1', searched_from: 'from4', click_target: 'targetZ', total_events: 1, mean_ordinality: 10.0),
      instance_double("ClickResponse", searched_repo: 'repo1', searched_from: 'from4', click_target: 'targetA', total_events: 10, mean_ordinality: 3.0),
      instance_double("ClickResponse", searched_repo: 'repo1', searched_from: 'from3', click_target: 'targetH', total_events: 100, mean_ordinality: 2.0),
      instance_double("ClickResponse", searched_repo: 'repo1', searched_from: 'from2', click_target: 'targetZ', total_events: 1, mean_ordinality: 10.0),
      instance_double("ClickResponse", searched_repo: 'repo3', searched_from: 'from3', click_target: 'targetH', total_events: 100, mean_ordinality: 2.0),
    ]

    query_segments = [
      instance_double("QueryResponse", searched_repo: 'repo1', searched_from: 'from2', total_events: 3),
      instance_double("QueryResponse", searched_repo: 'repo1', searched_from: 'from3', total_events: 130),
      instance_double("QueryResponse", searched_repo: 'repo1', searched_from: 'from4', total_events: 30),
      instance_double("QueryResponse", searched_repo: 'repo2', searched_from: 'from1', total_events: 1),
      instance_double("QueryResponse", searched_repo: 'repo3', searched_from: 'from3', total_events: 122),
    ]

    @events_processor = TermEventsProcessor.new(click_segments: clickthrough_segments, query_segments: query_segments, term: 'arbitrary')
  end

  describe "ordinality" do
    it "will calculate mean ordinality across multiple clicks segmented by repo" do
      expect(TermEventsProcessor.mean_ordinality_over_segments(@events_processor.click_segments[0..2])).to eql(240.0/111)
    end
    it "will return same average ordinality if one segment is given" do
      expect(TermEventsProcessor.mean_ordinality_over_segments(@events_processor.click_segments[1..1])).to eql(3.0)
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

    it "will return an array summarizing data from mutliple matching segment" do
      result_row = @events_processor.data_row_for_values({searched_repo: 'repo1', 'searched_from': 'from4'})
      expect(result_row).to eql(['arbitrary', 'repo1', 'from4', 30, 11, 0.37, 0.0122, 3.6])
    end

    it "will raise an error if no click or query segments match the specified values" do
      expect { @events_processor.data_row_for_values({searched_repo: 'repo1', 'searched_from': 'from1'}) }.to raise_error(NoEventSegmentsError)
    end

  end
  
  describe "process_data_for_dimensions" do

    it "will return output of `data_row_for_values` if no dimensions are specified" do
      report_array = @events_processor.process_data_for_dimensions([], values: {searched_repo: 'repo3', 'searched_from': 'from3'}) 
      expect(report_array).to eql([['arbitrary', 'repo3', 'from3', 122, 100, 0.82, 0.0067, 2.0]])
    end

    it "will return rows for each dimension permutation" do
      report_array = @events_processor.process_data_for_dimensions([:searched_from], values: {searched_repo: 'repo1'})
      expect(report_array).to eql([
        ['arbitrary', 'repo1', 'from2', 3, 1, 0.33, 0.1111, 10.0],
        ['arbitrary', 'repo1', 'from3', 130, 100, 0.77, 0.0059, 2.0],
        ['arbitrary', 'repo1', 'from4', 30, 11, 0.37, 0.0122, 3.6],
      ])
    end

  end

end
