Backend.PaymentsNewController = Ember.Controller.extend
  needs: ['order']
  order: Ember.computed.alias("controllers.order")