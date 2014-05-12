Backend.OrdersRoute = Ember.Route.extend
  model: ->
    Backend.Order.findAll()
    
  actions: 
    newOrder: ->
      route = this
      $.post("/api/checkouts").then (response) ->
        route.transitionTo('order', response.number)
