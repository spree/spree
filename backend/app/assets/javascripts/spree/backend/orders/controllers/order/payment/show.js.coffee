Backend.OrderPaymentShowController = Ember.ObjectController.extend
  actions:
    fire: (action) ->
      this.get('model').fire(action)
