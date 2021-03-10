$.fn.optionValueAutocomplete = function (options) {
  'use strict'

  // Default options
  options = options || {}
  var multiple = typeof (options.multiple) !== 'undefined' ? options.multiple : true
  var productSelect = options.productSelect
  var productId = options.productId
  var values = options.values
  var clearSelection = options.clearSelection

  function formatOptionValueList(values) {
    return values.map(function(obj) {
      return { id: obj.id, text: obj.name }
    })
  }

  function addOptions(select, productId, values) {
    $.ajax({
      type: 'GET',
      url: Spree.routes.option_values_api,
      dataType: 'json',
      data: {
        token: Spree.api_key,
        q: {
          id_in: values,
          variants_product_id_eq: productId
        }
      }
    }).then(function (data) {
      select.addSelect2Options(data)
    })
  }

  this.select2({
    multiple: multiple,
    minimumInputLength: 1,
    ajax: {
      url: Spree.routes.option_values_api,
      dataType: 'json',
      data: function (params) {
        var selectedProductId = typeof (productSelect) !== 'undefined' ? productSelect.val() : null

        var query = {
          q: {
            name_cont: params.term,
            variants_product_id_eq: selectedProductId
          },
          token: Spree.api_key
        }

        return query;
      },
      processResults: function(data) {
        var results = formatOptionValueList(data)

        return {
          results: results
        }
      }
    }
  })

  if (values && productId && !clearSelection) {
    addOptions(this, productId, values)
  }

  if (clearSelection) {
    this.val(null).trigger('change')
  }
}
