Backend.Payment = Ember.Object.extend
  fire: (action) ->
    order = @get 'order'
    url = Spree.pathFor("api/orders/#{order.number}/payments/#{payment.id}/#{action}")
      $.ajax
        method: 'PUT'
        url: url
      .done (response) ->
        order.refresh()