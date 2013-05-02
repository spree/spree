$ ->
  # Base Model for transfer line items
  class BulkVariant
    constructor: (@variant) ->
      @id = @variant.id
      @name = "#{@variant.name} - #{@variant.sku}"
      @quantity = 0

    add: (quantity) ->
      @quantity += quantity

  # Model for stock items which validate quantity with count on hand
  class BulkStockItem extends BulkVariant
    constructor: (@stock_item) ->
      super(@stock_item.variant)
      @count_on_hand = @stock_item.count_on_hand
      @name = "#{@variant.name} - #{@variant.sku} (#{@count_on_hand})"

    add: (quantity) ->
      @quantity += quantity
      @quantity = @count_on_hand if @quantity > @count_on_hand

  # Manages source and destination selections
  class BulkLocations
    constructor: ->
      @source = $('#source_location_id')
      @destination = $('#destination_location_id')

      @source.change => @populate_destination()

      $.getJSON "/api/stock_locations", (data) =>
        @locations = (location for location in data.stock_locations)
        @populate_source()
        @populate_destination()

    populate_source: ->
      @populate_select @source
      @source.trigger('change')

    populate_destination: ->
      @populate_select @destination, parseInt(@source.val())

    populate_select: (select, except=0) ->
      select.children('option').remove()
      for location in @locations when location.id isnt except
        select.append $('<option></option>')
                        .text(location.name)
                        .attr('value', location.id)
      select.select2()

  # Populates variants drop down
  class BulkVariants
    constructor: ->
      $('#source_location_id').change => @refresh_variants()

    receiving_stock: ->
      $( "#bulk_receive_stock:checked" ).length > 0

    refresh_variants: ->
      if @receiving_stock()
        @_refresh_bulk_variants()
      else
        @_refresh_bulk_stock_items()

    _refresh_bulk_variants: ->
      if @cached_variants?
        @populate_select @cached_variants
      else
        $.getJSON "/api/variants", (data) =>
          @cached_variants = _.map(data.variants, (variant) -> new BulkVariant(variant))
          @populate_select @cached_variants

    _refresh_bulk_stock_items: ->
      stock_location_id = $('#source_location_id').val()
      $.getJSON "/api/stock_locations/#{stock_location_id}/stock_items", (data) =>
        @populate_select _.map(data.stock_items, (stock_item) -> new BulkStockItem(stock_item))

    populate_select: (variants) ->
      $('#bulk_variant').children('option').remove()

      for variant in variants
        $('#bulk_variant').append($('<option></option>')
                                    .text(variant.name)
                                    .attr('value', variant.id)
                                    .data('variant', variant))

      $('#bulk_variant').select2()

  # Add/Remove variant line items
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
      quantity = parseInt $('#bulk_variant_quantity').val()

      variant = @find_or_add(variant)
      variant.add(quantity)
      @render()

    find_or_add: (variant) ->
      if existing = _.find(@variants, (v) -> v.id == variant.id)
        return existing
      else
        variant = $.extend({}, variant)
        @variants.push variant
        return variant

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

  # Main
  if $('#source_location_id').length > 0
    bulk_locations = new BulkLocations
    bulk_variants = new BulkVariants
    bulk_add_variants = new BulkAddVariants

    $('#bulk_receive_stock').click ->
      if this.checked
        $('#source_location_id_field').css('visibility', 'hidden')
      else
        $('#source_location_id_field').css('visibility', 'visible')

      $('#source_location_id').trigger('change')
