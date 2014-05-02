Backend.OrdersStatesCartController = Ember.ObjectController.extend
  needs: ['order']
  order: Ember.computed.alias("controllers.order")
  actions:
    showStockDetails: (variant) ->
      this.set('variant', Backend.Variant.create(variant))