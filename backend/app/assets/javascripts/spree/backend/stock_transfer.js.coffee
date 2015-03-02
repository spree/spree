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

      $.getJSON Spree.url(Spree.routes.stock_locations_api) + '?token=' + Spree.api_key, (data) =>
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
        $('#transfer_source_location_id_field').show()
      else
        $('#transfer_source_location_id_field').css('visibility', 'hidden')
        $('#transfer_source_location_id_field').hide()

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
        select.append $('<option></option>').text(location.name).attr('value', location.id)
      select.select2()

  # Populates variants drop down
  class TransferVariants
    constructor: ->
      $('#transfer_source_location_id').change => @refresh_variants()

    receiving_stock: ->
      $( "#transfer_receive_stock:checked" ).length > 0

    refresh_variants: ->
      if @receiving_stock()
        @_search_transfer_variants()
      else
        @_search_transfer_stock_items()

    _search_transfer_variants: ->
      @build_select(Spree.url(Spree.routes.variants_api), 'product_name_or_sku_cont')

    _search_transfer_stock_items: ->
      stock_location_id = $('#transfer_source_location_id').val()
      @build_select(Spree.url(Spree.routes.stock_locations_api + "/#{stock_location_id}/stock_items"),
        'variant_product_name_or_variant_sku_cont')

    format_variant_result: (result) ->
      "#{result.name} - #{result.sku}"

    build_select: (url, query) ->
      $('#transfer_variant').select2
        minimumInputLength: 3
        ajax:
          url: url
          datatype: "json"
          data: (term, page) ->
            query_object = {}
            query_object[query] = term
            q: query_object
            token: Spree.api_key

          results: (data, page) ->
            result = data["variants"] || data["stock_items"]
            # Format stock items as variants
            if data["stock_items"]?
              result = _(result).map (variant) ->
                variant.variant
            window.variants = result
            results: result

        formatResult: @format_variant_result
        formatSelection: (variant) ->
          if !!variant.options_text
            variant.name + " (#{variant.options_text})" + " - #{variant.sku}"
          else
            variant.name + " - #{variant.sku}"


  # Add/Remove variant line items
  class TransferAddVariants
    constructor: ->
      @variants = []
      @template = Handlebars.compile $('#transfer_variant_template').html()

      $('#transfer_source_location_id').change (event) => @clear_variants()

      $('button.transfer_add_variant').click (event) =>
        event.preventDefault()
        if $('#transfer_variant').select2('data')?
          @add_variant()
        else
          alert('Please select a variant first')

      $('#transfer-variants-table').on 'click', '.transfer_remove_variant', (event) =>
        event.preventDefault()
        @remove_variant $(event.target)

      $('button.transfer_transfer').click =>
        unless @variants.length > 0
          alert('no variants to transfer')
          false

    add_variant: ->
      variant = $('#transfer_variant').select2('data')
      quantity = parseInt $('#transfer_variant_quantity').val()

      variant = @find_or_add(variant)
      variant.add(quantity)
      @render()

    find_or_add: (variant) ->
      if existing = _.find(@variants, (v) -> v.id == variant.id)
        return existing
      else
        variant = new TransferVariant($.extend({}, variant))
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
