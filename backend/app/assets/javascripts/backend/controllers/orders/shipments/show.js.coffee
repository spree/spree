Backend.OrdersShipmentsShowController = Ember.ObjectController.extend

  shippingMethodID: (->
    @get('selected_shipping_rate.shipping_method_id')
  ).property("shippingMethodID")

  actions:
    editMethod: ->
      this.set('editingMethod', true)

    cancelMethod: ->
      this.set('editingMethod', false)

    saveMethod: ->
      controller = this
      url = Spree.pathFor("api/shipments/#{this.get('number')}")
      $.ajax
        method: 'PUT'
        url: url
        data:
          shipment:
            selected_shipping_rate_id: this.get('selected_shipping_rate_id')
      .done (response) ->
        controller.get('model').setProperties(response)
        controller.set('editingMethod', false)



