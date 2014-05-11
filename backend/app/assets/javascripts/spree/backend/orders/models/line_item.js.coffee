Backend.LineItem = Ember.Object.extend
  update: ->
    order_id = this.get('order.number')
    item = this
    $.ajax
      method: 'PUT'
      url: Spree.pathFor("api/orders/#{order_id}/line_items/#{@id}")
      data:
        line_item:
          quantity: item.get('quantity')
    .done (data) ->
      item.setProperties(data)
      item.get('order').refreshTotals()
  destroy: ->
    this.get('order').line_items.removeObject(this)

    order_id = this.get('order.number')
    item = this
    $.ajax
      method: 'DELETE'
      url: Spree.pathFor("api/orders/#{order_id}/line_items/#{@id}")
