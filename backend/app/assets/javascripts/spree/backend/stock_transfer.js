$(function () {
  function TransferVariant (variant1) {
    this.variant = variant1
    this.id = this.variant.id
    this.name = this.variant.name + ' - ' + this.variant.sku
    this.quantity = 0
  }
  TransferVariant.prototype.add = function (quantity) {
    this.quantity += quantity
    return this.quantity
  }

  function TransferLocations () {
    this.source = $('#transfer_source_location_id')
    this.destination = $('#transfer_destination_location_id')
    this.source.change(this.populate_destination.bind(this))
    $('#transfer_receive_stock').change(this.receive_stock_change.bind(this))
    $.getJSON(Spree.url(Spree.routes.stock_locations_api) + '?token=' + Spree.api_key + '&per_page=1000', function (data) {
      this.locations = (function () {
        var ref = data.stock_locations
        var results = []
        var i, len
        for (i = 0, len = ref.length; i < len; i++) {
          results.push(ref[i])
        }
        return results
      })()
      if (this.locations.length < 2) {
        this.force_receive_stock()
      }
      this.populate_source()
      this.populate_destination()
    }.bind(this))
  }

  TransferLocations.prototype.force_receive_stock = function () {
    $('#receive_stock_field').hide()
    $('#transfer_receive_stock').prop('checked', true)
    this.toggle_source_location(true)
  }

  TransferLocations.prototype.is_source_location_hidden = function () {
    return $('#transfer_source_location_id_field').css('visibility') === 'hidden'
  }

  TransferLocations.prototype.toggle_source_location = function (hide) {
    if (hide == null) {
      hide = false
    }
    this.source.trigger('change')
    var transferSourceLocationIdField = $('#transfer_source_location_id_field')
    if (this.is_source_location_hidden() && !hide) {
      transferSourceLocationIdField.css('visibility', 'visible')
      transferSourceLocationIdField.show()
    } else {
      transferSourceLocationIdField.css('visibility', 'hidden')
      transferSourceLocationIdField.hide()
    }
  }

  TransferLocations.prototype.receive_stock_change = function (event) {
    this.toggle_source_location(event.target.checked)
    this.populate_destination(!event.target.checked)
  }

  TransferLocations.prototype.populate_source = function () {
    this.populate_select(this.source)
    this.source.trigger('change')
  }

  TransferLocations.prototype.populate_destination = function () {
    if (this.is_source_location_hidden()) {
      return this.populate_select(this.destination)
    } else {
      return this.populate_select(this.destination, parseInt(this.source.val()))
    }
  }

  TransferLocations.prototype.populate_select = function (select, except) {
    var i, len, location, ref
    if (except == null) {
      except = 0
    }
    select.children('option').remove()
    ref = this.locations
    for (i = 0, len = ref.length; i < len; i++) {
      location = ref[i]
      if (location.id !== except) {
        select.append($('<option></option>').text(location.name).attr('value', location.id))
      }
    }
    return select.select2()
  }

  function TransferVariants () {
    $('#transfer_source_location_id').change(this.refresh_variants.bind(this))
  }

  TransferVariants.prototype.receiving_stock = function () {
    return $('#transfer_receive_stock:checked').length > 0
  }

  TransferVariants.prototype.refresh_variants = function () {
    if (this.receiving_stock()) {
      return this._search_transfer_variants()
    } else {
      return this._search_transfer_stock_items()
    }
  }

  TransferVariants.prototype._search_transfer_variants = function () {
    return this.build_select(Spree.url(Spree.routes.variants_api), 'product_name_or_sku_cont')
  }

  TransferVariants.prototype._search_transfer_stock_items = function () {
    var stockLocationId = $('#transfer_source_location_id').val()
    return this.build_select(Spree.url(Spree.routes.stock_locations_api + ('/' + stockLocationId + '/stock_items')), 'variant_product_name_or_variant_sku_cont')
  }

  TransferVariants.prototype.format_variant_result = function (result) {
    // eslint-disable-next-line no-extra-boolean-cast
    if (!!result.options_text) {
      return result.name + ' - ' + result.sku + ' (' + result.options_text + ')'
    } else {
      return result.name + ' - ' + result.sku
    }
  }

  TransferVariants.prototype.build_select = function (url, query) {
    return $('#transfer_variant').select2({
      minimumInputLength: 3,
      ajax: {
        url: url,
        datatype: 'json',
        data: function (term) {
          var q = {}
          q[query] = term
          return {
            q: q,
            token: Spree.api_key
          }
        },
        results: function (data) {
          var result = data['variants'] || data['stock_items']
          if (data['stock_items'] != null) {
            result = _(result).map(function (variant) {
              return variant.variant
            })
          }
          window.variants = result
          return {
            results: result
          }
        }
      },
      formatResult: this.format_variant_result,
      formatSelection: function (variant) {
        // eslint-disable-next-line no-extra-boolean-cast
        if (!!variant.options_text) {
          return variant.name + (' (' + variant.options_text + ')') + (' - ' + variant.sku)
        } else {
          return variant.name + (' - ' + variant.sku)
        }
      }
    })
  }

  function TransferAddVariants () {
    this.variants = []
    this.template = Handlebars.compile($('#transfer_variant_template').html())
    $('#transfer_source_location_id').change(this.clear_variants.bind(this))
    $('button.transfer_add_variant').click(function (event) {
      event.preventDefault()
      if ($('#transfer_variant').select2('data') != null) {
        this.add_variant()
      } else {
        alert('Please select a variant first')
      }
    }.bind(this))
    $('#transfer-variants-table').on('click', '.transfer_remove_variant', function (event) {
      event.preventDefault()
      this.remove_variant($(event.target))
    }.bind(this))
    $('button.transfer_transfer').click(function () {
      if (!(this.variants.length > 0)) {
        alert('no variants to transfer')
        return false
      }
    }.bind(this))
  }

  TransferAddVariants.prototype.add_variant = function () {
    var variant = $('#transfer_variant').select2('data')
    var quantity = parseInt($('#transfer_variant_quantity').val())
    variant = this.find_or_add(variant)
    variant.add(quantity)
    return this.render()
  }

  TransferAddVariants.prototype.find_or_add = function (variant) {
    var existing = _.find(this.variants, function (v) {
      return v.id === variant.id
    })
    if (existing) {
      return existing
    } else {
      variant = new TransferVariant($.extend({}, variant))
      this.variants.push(variant)
      return variant
    }
  }

  TransferAddVariants.prototype.remove_variant = function (target) {
    var v
    var variantId = parseInt(target.data('variantId'))
    this.variants = (function () {
      var ref = this.variants
      var results = []
      var i, len
      for (i = 0, len = ref.length; i < len; i++) {
        v = ref[i]
        if (v.id !== variantId) {
          results.push(v)
        }
      }
      return results
    }.call(this))
    return this.render()
  }

  TransferAddVariants.prototype.clear_variants = function () {
    this.variants = []
    return this.render()
  }

  TransferAddVariants.prototype.contains = function (id) {
    return _.contains(_.pluck(this.variants, 'id'), id)
  }

  TransferAddVariants.prototype.render = function () {
    if (this.variants.length === 0) {
      $('#transfer-variants-table').hide()
      return $('.no-objects-found').show()
    } else {
      $('#transfer-variants-table').show()
      $('.no-objects-found').hide()
      return $('#transfer_variants_tbody').html(this.template({
        variants: this.variants
      }))
    }
  }

  if ($('#transfer_source_location_id').length > 0) {
    /* eslint-disable no-new */
    new TransferLocations()
    new TransferVariants()
    new TransferAddVariants()
    /* eslint-enable no-new */
  }
})
