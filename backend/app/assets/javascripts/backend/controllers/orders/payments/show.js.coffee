Backend.OrdersPaymentsShowController = Ember.ObjectController.extend
  actions:
    fire: (action) ->
      order = this.get('model.order')
      payment = this.get('model')
      url = Spree.pathFor("api/orders/#{order.number}/payments/#{payment.id}/#{action}")
      $.ajax
        method: 'PUT'
        url: url
      .done (response) ->
        order.refresh()
