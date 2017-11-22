describe QueryResponse do
  it { is_expected.to respond_to(:search_term)   }
  it { is_expected.to respond_to(:action)        }
  it { is_expected.to respond_to(:total_events)  }
  it { is_expected.to respond_to(:unique_events) }
  it { is_expected.to respond_to(:dimensions)  }
end
