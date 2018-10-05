$.fn.productAutocomplete = function (options) {
  'use strict'

  // Default options
  options = options || {}
  var multiple = typeof (options.multiple) !== 'undefined' ? options.multiple : true

  function formatProduct (product) {
    return Select2.util.escapeMarkup(product.name)
  }

  this.select2({
    minimumInputLength: 3,
    multiple: multiple,
    initSelection: function (element, callback) {
      $.get(Spree.routes.products_api, {
        ids: element.val().split(','),
        token: Spree.api_key
      }, function (data) {
        callback(multiple ? data.products : data.products[0])
      })
    },
    ajax: {
      url: Spree.routes.products_api,
      datatype: 'json',
      cache: true,
      data: function (term, page) {
        return {
          q: {
            name_or_master_sku_cont: term
          },
          m: 'OR',
          token: Spree.api_key
        }
      },
      results: function (data, page) {
        var products = data.products ? data.products : []
        return {
          results: products
        }
      }
    },
    formatResult: formatProduct,
    formatSelection: formatProduct
  })
}

$(document).ready(function () {
  $('.product_picker').productAutocomplete()
})
