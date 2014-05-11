Backend.OrderItemsController = Ember.ObjectController.extend
  actions:
    showStockDetails: (variant) ->
      this.set('variant', Backend.Variant.create(variant))