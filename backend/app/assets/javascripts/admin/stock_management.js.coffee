jQuery ->
  $('.stock_item_backorderable').live 'click', ->
    $(@).parent('form').submit()
  $('.toggle_stock_item_backorderable').submit ->
    $.ajax
      type: @method
      url: @action
      data: $(@).serialize()
    false
