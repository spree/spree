$.fn.optionValueAutocomplete = function (options) {
  'use strict'

  // Default options
  options = options || {}
  var multiple = typeof (options.multiple) !== 'undefined' ? options.multiple : true
  var productSelect = options.productSelect

  function formatOptionValueList(values) {
    var formatted_data = $.map(values, function (obj) {
      var item = { id: obj.id, text: obj.name }

      return item
    });

    return formatted_data
  }

  this.select2({
    multiple: multiple,
    minimumInputLength: 2,
    allowClear: true,
    ajax: {
      url: Spree.routes.option_values_api,
      dataType: 'json',
      data: function (params) {
        var productId = typeof (productSelect) !== 'undefined' ? $(productSelect).select2('val') : null

        var query = {
          q: {
            name_cont: params.term,
            variants_product_id_eq: productId
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
}
