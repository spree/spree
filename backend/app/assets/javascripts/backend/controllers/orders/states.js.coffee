Backend.OrdersStatesController = Ember.ObjectController.extend
  needs: ['order']
  order: Ember.computed.alias("controllers.order")
  contentBinding: 'controllers.order'