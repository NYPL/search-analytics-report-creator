QUERY_SENT = 'QuerySent'
CLICKTHROUGH = 'Clickthrough'

CONFIG = {
  reportable_dimensions: {
    searched_repo: {
      ga_dimension: 2,
      events: [QUERY_SENT, CLICKTHROUGH]
    },
  },
  dimensions: [:searched_repo, :searched_from]
}
