Backend.Variant = Backend.BaseModel.extend
  associations: ->
    stock_items: Backend.StockItem

  associate: (item) ->
    item.set('variant', this)