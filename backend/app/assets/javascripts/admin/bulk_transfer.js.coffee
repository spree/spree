$ ->
  refresh_variants = ->
    stock_location_id = $('#source_location_id').val()

    $.getJSON "/api/stock_locations/#{stock_location_id}/stock_items", (data) ->
      $('#bulk_variant option').remove()

      _.each data.stock_items, (item) ->
        option = $('<option></option>')
                   .text("#{item.variant.name}-#{item.variant.sku} (#{item.count_on_hand})")
                   .attr('value', item.variant.id)
                   .data('count_on_hand', item.count_on_hand)

        $('#bulk_variant').append(option)

      $('#bulk_variant').select2()

  refresh_variants()

  $('#source_location_id').change refresh_variants

  $('#bulk_receive_stock').click ->
    if this.checked
      $('#source_location_id_field').css('visibility', 'hidden')
    else
      $('#source_location_id_field').css('visibility', 'visible')

  $('button.bulk_remove_variant').live 'click', (event) ->
    event.preventDefault()
    $(this).parents('tr').remove()

    if $('#transfer-variants-table').find('tr').length < 2
      $('#transfer-variants-table').hide()
      $('.no-objects-found').show()

  $('button.bulk_add_variant').click (event) ->
    if $('#transfer-variants-table:hidden')
      $('#transfer-variants-table:hidden').show()
      $('.no-objects-found').hide()

    event.preventDefault()

    source = $('#bulk_variant_template').html()
    template = Handlebars.compile(source)

    variant_name = $('#bulk_variant option:selected').text()
    variant_id = $('#bulk_variant option:selected').val()
    quantity = $('#bulk_variant_quantity').val()

    rendered = template
      name: variant_name
      id: variant_id
      quantity: quantity

    $('#bulk_variants_tbody').append(rendered)

  $('button.bulk_transfer').click ->
    unless $('input#variant\\[\\]').length > 0
      alert('no variants to transfer')
      false
