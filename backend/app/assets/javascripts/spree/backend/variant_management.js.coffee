jQuery ->
  $('.track_inventory_checkbox').on 'click', ->
    $(@).parents('form').submit()
  $('.toggle_variant_track_inventory').on 'submit', ->
    $.ajax
      type: @method
      url: @action
      data: $(@).serialize()
    false
