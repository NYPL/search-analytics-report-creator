QUERY_SENT = 'QuerySent'
CLICKTHROUGH = 'Clickthrough'

CONFIG = {
  reportable_dimensions: {
    searched_from: {
      ga_index: 1,
      events: [QUERY_SENT, CLICKTHROUGH]
    },
    searched_repo: {
      ga_index: 2,
      events: [QUERY_SENT, CLICKTHROUGH]
    },
  },
  dimensions: [:searched_repo, :searched_from]
}
