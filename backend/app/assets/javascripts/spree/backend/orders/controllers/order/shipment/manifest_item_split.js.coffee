Backend.OrderShipmentManifestItemSplitController = Ember.ObjectController.extend
  shipments: (->
    this.get('model.shipment.order.shipments')
  ).property("shipments")

  actions:
    edit: ->
      this.set('editing', true)
    save: ->
      this.set('editing', false)
      variant_id = this.get('model.variant_id')
      original_quantity = this.get('model.original_quantity')
      quantity = this.get('model.quantity')
      this.get('shipment').adjustItems(variant_id, quantity, original_quantity)
    cancel: ->
      this.set('editing', false)
    split: ->
      this.set('splitting', true)
    delete: ->
      variant_id = this.get('model.variant_id')
      original_quantity = this.get('model.original_quantity')
      if confirm(Spree.translations.are_you_sure_delete)
        this.get('shipment').adjustItems(variant_id, 0, original_quantity)
