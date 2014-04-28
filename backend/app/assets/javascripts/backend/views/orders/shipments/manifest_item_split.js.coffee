Backend.OrdersShipmentsManifestItemSplitView = Ember.View.extend
  didInsertElement: ->
    $('select.item_stock_location').select2()