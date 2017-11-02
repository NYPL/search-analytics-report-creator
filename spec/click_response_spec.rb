describe ClickResponse do
  it { is_expected.to respond_to(:search_term)    }
  it { is_expected.to respond_to(:action)         }
  it { is_expected.to respond_to(:total_events)   }
  it { is_expected.to respond_to(:unique_events)  }
  it { is_expected.to respond_to(:mean_ordinality) }
  it { is_expected.to respond_to(:click_target)   }
  it { is_expected.to respond_to(:searched_from)  }
  it { is_expected.to respond_to(:searched_repo)  }
end
