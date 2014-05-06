Backend.StockItem = Ember.Object.extend
  # Default quantity for the stock picker form
  quantity: (->
    1
  ).property('quantity')