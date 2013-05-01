$ ->
  class BulkLocations
    constructor: (@source, @destination) ->
      @source.change => @populate_destination()

      $.getJSON "/api/stock_locations", (data) =>
        @locations = (location for location in data.stock_locations)
        @populate_source()
        @populate_destination()

    populate_source: ->
      @populate_select @source

    populate_destination: ->
      @populate_select @destination, parseInt(@source.val())

    populate_select: (select, except=0) ->
      select.children('option').remove()
      for location in @locations when location.id isnt except
        select.append $('<option></option>')
                        .text(location.name)
                        .attr('value', location.id)
      select.select2()

  class BulkVariants
    constructor: ->
      @refresh_variants()
      $('#source_location_id').change => @refresh_variants()

    refresh_variants: ->
      stock_location_id = $('#source_location_id').val()

      $.getJSON "/api/stock_locations/#{stock_location_id}/stock_items", (data) =>
        @populate_select data.stock_items

    populate_select: (stock_items) ->
      $('#bulk_variant').children('option').remove()

      for item in stock_items
        $('#bulk_variant').append($('<option></option>')
                                    .text("#{item.variant.name}-#{item.variant.sku} (#{item.count_on_hand})")
                                    .attr('value', item.variant.id)
                                    .data('count_on_hand', item.count_on_hand)
                                    .data('variant', item.variant))

      $('#bulk_variant').select2()

  class BulkAddVariants
    constructor: ->
      @variants = []
      @template = Handlebars.compile $('#bulk_variant_template').html()

      $('#source_location_id').change (event) => @clear_variants()

      $('button.bulk_add_variant').click (event) =>
        event.preventDefault()
        @add_variant()

      $('#transfer-variants-table').on 'click', '.bulk_remove_variant', (event) =>
        event.preventDefault()
        @remove_variant $(event.target)

      $('button.bulk_transfer').click =>
        unless @variants.length > 0
          alert('no variants to transfer')
          false

    add_variant: ->
      variant = $('#bulk_variant option:selected').data('variant')
      count_on_hand = parseInt $('#bulk_variant option:selected').data('count_on_hand')
      quantity = parseInt $('#bulk_variant_quantity').val()

      if existing = _.find(@variants, (v) -> v.id == variant.id)
        existing.quantity += quantity
      else
        @variants.push $.extend({ quantity: quantity }, variant)

      @render()

    remove_variant: (target) ->
      variant_id = parseInt(target.data('variantId'))
      @variants = (v for v in @variants when v.id isnt variant_id)
      @render()

    clear_variants: ->
      @variants = []
      @render()

    contains: (id) ->
      _.contains(_.pluck(@variants, 'id'), id)

    render: ->
      if @variants.length is 0
        $('#transfer-variants-table').hide()
        $('.no-objects-found').show()
      else
        $('#transfer-variants-table').show()
        $('.no-objects-found').hide()

        rendered = @template { variants: @variants }
        $('#bulk_variants_tbody').html(rendered)

  if $('#source_location_id').length > 0
    new BulkLocations $('#source_location_id'), $('#destination_location_id')
    new BulkVariants
    new BulkAddVariants

    $('#bulk_receive_stock').click ->
      if this.checked
        $('#source_location_id_field').css('visibility', 'hidden')
      else
        $('#source_location_id_field').css('visibility', 'visible')
