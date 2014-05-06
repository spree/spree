Backend.OrdersVariantsStockPickerController = Ember.ObjectController.extend
  needs: ['order']
  order: Ember.computed.alias("controllers.order")

  actions:
    add: (stock_item) ->
      variant = this.parentController.get('variant')
      this.parentController.set('variant', null)
      quantity = stock_item.get('quantity')

      this.get('order.content').addItem(variant, quantity)