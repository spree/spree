Backend.OrderShipmentManifestItemController = Ember.ObjectController.extend
  image: ( ->
    @get('variant.images.firstObject.mini_url')
  ).property("image")
  states: (->
    $.map @get("model.states"), (state, count) ->
      count + " x " + state
  ).property("states")
  canUpdate: (->
    this.get('shipment.permissions.can_update')
  ).property("canUpdate")

  shipment: (->
    this.get('model.shipment')
  ).property("shipment")

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
    beginSplit: ->
      this.set('splitting', true)
    split: ->
      # Pending jhawthorn's splitter API endpoint
    delete: ->
      variant_id = this.get('model.variant_id')
      original_quantity = this.get('model.original_quantity')
      if confirm(Spree.translations.are_you_sure_delete)
        this.get('shipment').adjustItems(variant_id, 0, original_quantity)
