Backend.OrderShipmentShowController = Ember.ObjectController.extend

  shippingMethodID: (->
    @get('selected_shipping_rate.shipping_method_id')
  ).property("shippingMethodID")

  actions:
    editMethod: ->
      this.set('editingMethod', true)

    cancelMethod: ->
      this.set('editingMethod', false)

    saveMethod: ->
      this.get('model').updateShippingRate()
      this.set('editingMethod', false)

    editTracking: ->
      this.set('editingTracking', true)

    cancelTracking: ->
      this.set('editingTracking', false)

    saveTracking: ->
      this.get('model').updateTracking()
      this.set('editingTracking', false)



