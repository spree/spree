Backend.OrdersStatesCartController = Backend.OrdersStatesController.extend
  actions:
    showStockDetails: (variant) ->
      this.set('variant', Backend.Variant.create(variant))