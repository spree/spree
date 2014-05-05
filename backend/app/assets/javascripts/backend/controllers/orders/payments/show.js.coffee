Backend.OrdersPaymentsShowController = Ember.ObjectController.extend
  actions:
    fire: (action) ->
      this.get('model').fire(action)
