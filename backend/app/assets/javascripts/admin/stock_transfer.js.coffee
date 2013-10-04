$ ->
  # Base Model for transfer line items
  class TransferVariant
    constructor: (@variant) ->
      @id = @variant.id
      @name = "#{@variant.name} - #{@variant.sku}"
      @quantity = 0

    add: (quantity) ->
      @quantity += quantity

  # Model for stock items which validate quantity with count on hand
  class TransferStockItem extends TransferVariant
    constructor: (@stock_item) ->
      super(@stock_item.variant)
      @count_on_hand = @stock_item.count_on_hand
      @name = "#{@variant.name} - #{@variant.sku} (#{@count_on_hand})"

    add: (quantity) ->
      @quantity += quantity
      @quantity = @count_on_hand if @quantity > @count_on_hand

  # Manages source and destination selections
  class TransferLocations
    constructor: ->
      @source = $('#transfer_source_location_id')
      @destination = $('#transfer_destination_location_id')

      @source.change => @populate_destination()

      $('#transfer_receive_stock').change (event) => @receive_stock_change(event)

      $.getJSON Spree.url(Spree.routes.stock_locations_api), (data) =>
        @locations = (location for location in data.stock_locations)
        @force_receive_stock() if @locations.length < 2

        @populate_source()
        @populate_destination()

    force_receive_stock: ->
      $('#receive_stock_field').hide()
      $('#transfer_receive_stock').prop('checked', true)
      @toggle_source_location true

    is_source_location_hidden: ->
      $('#transfer_source_location_id_field').css('visibility') == 'hidden'

    toggle_source_location: (hide=false) ->
      @source.trigger('change')
      if @is_source_location_hidden() and not hide
        $('#transfer_source_location_id_field').css('visibility', 'visible')
      else
        $('#transfer_source_location_id_field').css('visibility', 'hidden')

    receive_stock_change: (event) ->
      @toggle_source_location event.target.checked
      @populate_destination(!event.target.checked)

    populate_source: ->
      @populate_select @source
      @source.trigger('change')

    populate_destination: (except_source=true) ->
      if @is_source_location_hidden()
        @populate_select @destination
      else
        @populate_select @destination, parseInt(@source.val())

    populate_select: (select, except=0) ->
      select.children('option').remove()
      for location in @locations when location.id isnt except
        select.append $('<option></option>')
                        .text(location.name)
                        .attr('value', location.id)
      select.select2()

  # Populates variants drop down
  class TransferVariants
    constructor: ->
      $('#transfer_source_location_id').change => @refresh_variants()

    receiving_stock: ->
      $( "#transfer_receive_stock:checked" ).length > 0

    refresh_variants: ->
      if @receiving_stock()
        @_refresh_transfer_variants()
      else
        @_refresh_transfer_stock_items()

    _refresh_transfer_variants: ->
      if @cached_variants?
        @populate_select @cached_variants
      else
        $.getJSON Spree.url(Spree.routes.variants_api), (data) =>
          @cached_variants = _.map(data.variants, (variant) -> new TransferVariant(variant))
          @populate_select @cached_variants

    _refresh_transfer_stock_items: ->
      stock_location_id = $('#transfer_source_location_id').val()
      $.getJSON Spree.url(Spree.routes.stock_locations_api + "/#{stock_location_id}/stock_items"), (data) =>
        @populate_select _.map(data.stock_items, (stock_item) -> new TransferStockItem(stock_item))

    populate_select: (variants) ->
      $('#transfer_variant').children('option').remove()

      for variant in variants
        $('#transfer_variant').append($('<option></option>')
                                    .text(variant.name)
                                    .attr('value', variant.id)
                                    .data('variant', variant))

      $('#transfer_variant').select2()

  # Add/Remove variant line items
  class TransferAddVariants
    constructor: ->
      @variants = []
      @template = Handlebars.compile $('#transfer_variant_template').html()

      $('#transfer_source_location_id').change (event) => @clear_variants()

      $('button.transfer_add_variant').click (event) =>
        event.preventDefault()
        @add_variant()

      $('#transfer-variants-table').on 'click', '.transfer_remove_variant', (event) =>
        event.preventDefault()
        @remove_variant $(event.target)

      $('button.transfer_transfer').click =>
        unless @variants.length > 0
          alert('no variants to transfer')
          false

    add_variant: ->
      variant = $('#transfer_variant option:selected').data('variant')
      quantity = parseInt $('#transfer_variant_quantity').val()

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
        $('#transfer_variants_tbody').html(rendered)

  # Main
  if $('#transfer_source_location_id').length > 0
    transfer_locations = new TransferLocations
    transfer_variants = new TransferVariants
    transfer_add_variants = new TransferAddVariants
