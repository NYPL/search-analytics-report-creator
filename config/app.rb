QUERY_SENT = 'QuerySent'
CLICKTHROUGH = 'Clickthrough'

CONFIG = {
  reportable_dimensions: {
    searched_from: {
      title: 'Searched From',
      ga_index: 1,
      events: [QUERY_SENT, CLICKTHROUGH]
    },
    searched_repo: {
      title: 'Searched Repo',
      ga_index: 2,
      events: [QUERY_SENT, CLICKTHROUGH]
    },
    click_target: {
      ga_index: 3,
      events: [CLICKTHROUGH]
    }
  },
}
