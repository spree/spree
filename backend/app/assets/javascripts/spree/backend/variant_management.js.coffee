jQuery ->
  $('.track_inventory_checkbox').on 'click', ->
    $(this).siblings('.variant_track_inventory').val($(this).is(':checked'))
    $(this).parents('form').submit()
  $('.toggle_variant_track_inventory').on 'submit', ->
    $.ajax
      type: @method
      url: @action
      data: $(this).serialize()
    false
