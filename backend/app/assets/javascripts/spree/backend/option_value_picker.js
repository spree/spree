$.fn.optionValueAutocomplete = function (options) {
  'use strict'

  // Default options
  options = options || {}
  var multiple = typeof (options.multiple) !== 'undefined' ? options.multiple : true
  var productSelect = options.productSelect
  var productId = options.productId
  var values = options.values
  var clearSelection = options.clearSelection

  function addOptions(select, productId, values) {
    $.ajax({
      type: 'GET',
      url: Spree.routes.option_values_api_v2,
      headers: Spree.apiV2Authentication(),
      dataType: 'json',
      data: {
        filter: {
          id_in: values,
          variants_product_id_eq: productId
        }
      }
    }).then(function (data) {
      select.addSelect2Options(data.data)
    })
  }

  this.select2({
    multiple: multiple,
    minimumInputLength: 1,
    ajax: {
      url: Spree.routes.option_values_api_v2,
      dataType: 'json',
      headers: Spree.apiV2Authentication(),
      data: function (params) {
        var selectedProductId = typeof (productSelect) !== 'undefined' ? productSelect.val() : null

        return {
          filter: {
            name_cont: params.term,
            variants_product_id_eq: selectedProductId
          }
        }
      },
      processResults: function(data) {
        return formatSelect2Options(data)
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
