$(function () {
  $('.stock_item_backorderable').on('click', function () {
    $(this).parent('form').submit()
  })
  $('.toggle_stock_item_backorderable').on('submit', function () {
    $.ajax({
      type: this.method,
      url: this.action,
      data: $(this).serialize(),
      dataType: 'json'
    })
    return false
  })
})
