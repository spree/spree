Backend.OrdersRoute = Ember.Route.extend
  model: ->
    Backend.Order.findAll()

  renderTemplate: ->
    this.render 'orders/index'
    this.render 'orders/index_actions', { outlet: 'actions', into: 'application' }
    this.controllerFor('application').set('showSidebar', false)
    this.controllerFor('application').set('title', 'Listing Orders')

  actions: 
    newOrder: ->
      route = this
      $.post("/api/checkouts").then (response) ->
        route.transitionTo('order', response.number)
