Backend.OrdersVariantsStockPickerController = Ember.ObjectController.extend
  actions:
    add: (stock_item) ->
      variant = this.parentController.get('variant')
      this.parentController.set('variant', null)
      order = this.parentController.parentController.content
      quantity = stock_item.get('quantity')

      order.addItem(variant, quantity)