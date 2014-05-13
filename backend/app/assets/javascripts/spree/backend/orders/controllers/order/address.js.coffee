Backend.OrderAddressController = Ember.ObjectController.extend
  needs: ['order']
  order: Ember.computed.alias("controllers.order")
  
  init: ->
    @set('guestCheckout', false)
  guestCheckout: (->
    !@get('user_id')
  ).property('guestCheckout')
  hasUser: (->
    !@get('guestCheckout')
  ).property('hasUser').volatile()

  actions:
    toggleUseBilling: ->
      this.set('useBilling', !this.get('useBilling'))
    pickedCustomer: (customer) ->
      this.get('order').set('bill_address', Backend.Address.create(customer.bill_address))
      this.get('order').set('ship_address', Backend.Address.create(customer.ship_address))

    update: ->
      if this.get('hasUser')
        params = {
          user_id: @get('user_id')
        }
      else
        params = {
          email: @get('email')
        }

      params.bill_address_attributes = @get('bill_address.formParams')
      params.ship_address_attributes = @get('ship_address.formParams')

      order = this.get('order.content')
      order.update(params).then ->
        order.advance()