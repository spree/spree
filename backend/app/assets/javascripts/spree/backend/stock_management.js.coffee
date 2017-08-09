jQuery ->
  $('[data-hook="admin_stock_inventory_management"]').on 'click', '.stock_item_backorderable', ->
    $(@).parent('form').submit()
  $('[data-hook="admin_stock_inventory_management"]').on 'submit', '.toggle_stock_item_backorderable', ->
    $.ajax
      type: @method
      url: @action
      data: $(@).serialize()
    false
