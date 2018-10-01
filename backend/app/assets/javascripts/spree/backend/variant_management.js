$(function () {
  $('.track_inventory_checkbox').on('click', function () {
    $(this).siblings('.variant_track_inventory').val($(this).is(':checked'))
    $(this).parents('form').submit()
  })
  $('.toggle_variant_track_inventory').on('submit', function () {
    $.ajax({
      type: this.method,
      url: this.action,
      data: $(this).serialize()
    })
    return false
  })
})
