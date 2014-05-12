Backend.Order = Backend.BaseModel.extend({})

Backend.Order.reopenClass
  urlRoot: Spree.pathFor('api/orders')

  findAll: ->
    Em.$.ajax
      url: this.urlRoot
    .then (data) ->
      Ember.run () ->
        orders = Em.A();
        incoming_orders = data.orders
        orders.pushObjects(incoming_orders.map (order) ->
          Backend.Order.create(order)
        )

  find: (number) ->
    Em.$.ajax
      url: "#{this.urlRoot}/#{number}"
    .then (data) ->
      Ember.run () ->
        Backend.Order.create(data)


Backend.Order.reopen
  associations: ->
    line_items: Backend.LineItem
    bill_address: Backend.Address
    ship_address: Backend.Address
    shipments: Backend.Shipment
    payments: Backend.Payment

  associate: (item) ->
    item.set('order', this)

  url: (->
    this.constructor.urlRoot + "/" + this.get('number')
  ).property('url')

  variants: (->
    $.map @get('line_items'), (item) ->
      Backend.Variant.create(item.variant)
  ).property('variants')

  variantByID: (variant_id) ->
    this.get('variants').find (variant) ->
      variant.id == variant_id

  lineItemByVariantID: (variant_id) ->
    item = @get('line_items').find (line_item) ->
      line_item.variant.id == variant_id

  canUpdate: (->
    @get('permissions.can_update')
  ).property('canUpdate')

  addItem: (variant, quantity) ->
    order = this
    $.ajax
      method: 'POST'
      url: Spree.pathFor("api/orders/#{order.number}/line_items")
      data:
        line_item:
          variant_id: variant.id
          quantity: quantity
    .done ->
      if order.state == 'cart'
        order.advance()
      else
        order.refresh()

  update: (params) ->
    order = this
    $.ajax
      method: 'PUT'
      url: this.get('url')
      data: { order: params }
    .then (data) ->
      order.setProperties(data)
      order.init()

  refresh: ->
    order = this
    $.ajax
      method: 'GET'
      url: this.get('url')
    .then (data) ->
      order.setProperties(data)
      order.init()

  refreshTotals: ->
    order = this
    $.ajax
      method: 'GET'
      url: this.get('url') + '/sidebar'
    .then (data) ->
      order.setProperties(data)
      
  advance: ->
    order = this
    url = Spree.pathFor("api/checkouts/#{order.number}/advance")

    $.ajax
      url: url
      method: "PUT"
    .done (data) ->
      order.setProperties(data)
      order.init()

  states: (->
    states = this.get('checkout_steps')
    states.unshift("cart")
    confirm_index = states.indexOf('confirm')
    if confirm_index > -1
      states.splice(confirm_index, 1)
    # Remove complete state
    unless this.get('completed_at')
      states.pop()
    states
  ).property('states')

