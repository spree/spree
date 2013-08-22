jQuery ->
  $('.stock_item_backorderable').on 'click', ->
    $(@).parent('form').submit()
  $('.toggle_stock_item_backorderable').on 'submit', ->
    $.ajax
      type: @method
      url: @action
      data: $(@).serialize()
    false
