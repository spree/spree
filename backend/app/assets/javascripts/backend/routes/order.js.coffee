Backend.OrderRoute = Ember.Route.extend
  model: (params) ->
    this.store.find('order', params.order_number).then (order) ->
      # TODO: This needs to be passed to the view, but I am not convinced
      # if this is the best way to do it. Therefore it's probably wrong.
      order.set('current_state', params.state || order.get('state'))

  serialize: (model) ->
    { order_number: model.get('number') }

  renderTemplate: ->
    @render 'orders/show'

    order = @currentModel
    # Set the title
    app_controller = @controllerFor('application')
    app_controller.set('title', "Order ##{order.get('number')}")
    @render 'orders/show_actions', { outlet: 'actions', into: 'application' }

    # Show the sidebar
    app_controller.set('showSidebar', true)
    @render 'orders/sidebar', { outlet: 'sidebar', into: 'application' }

  actions:
    cancel: ->
      route = this
      if confirm("Are you sure you want to cancel this order?")
        $.ajax
          url: Spree.pathFor("/api/orders/#{this.currentModel.number}/cancel")
          type: "PUT"
        .then (response) ->
          this.transitionTo('order', response.number)