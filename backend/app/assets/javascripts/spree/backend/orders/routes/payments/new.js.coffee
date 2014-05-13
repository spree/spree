Backend.PaymentsNewRoute = Ember.Route.extend
  model: ->
    Backend.Payment.create
      name: 'Foobar'
      source: Backend.PaymentSource.create(number: '1111')

  actions:
    chooseMethod: (payment_method) ->
      this.render("payment_methods/#{payment_method.method_type}", { into: 'payments.new', outlet: 'payment_method'} )
