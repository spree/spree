Backend.OrderStateRoute = Ember.Route.extend
  model: (params) ->
    params.state

  renderTemplate: ->
    @render "orders/states/#{this.currentModel}", { outlet: 'state' }