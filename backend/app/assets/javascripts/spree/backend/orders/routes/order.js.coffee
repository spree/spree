Backend.OrderRoute = Ember.Route.extend
  model: (params) ->
    this.store.find('order', params.order_number)