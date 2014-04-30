Backend.OrdersStatesCartController = Ember.ObjectController.extend
  actions:
    showStockDetails: (variant) ->
      this.set('variant', Backend.Variant.create(variant))