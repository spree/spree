$.fn.productAutocomplete = function (options) {
  'use strict'

  // Default options
  options = options || {}
  var multiple = typeof (options.multiple) !== 'undefined' ? options.multiple : true
  var values = typeof (options.values) !== 'undefined' ? options.values : null

  function formatProductList(products) {
    return products.map(function(obj) {
      return { id: obj.id, text: obj.name }
    })
  }

  function addOptions(select, values) {
    $.ajax({
      url: Spree.routes.products_api,
      dataType: 'json',
      data: {
        q: {
          id_in: values
        },
        token: Spree.api_key
      }
    }).then(function (data) {
      select.addSelect2Options(data.products)
    })
  }

  this.select2({
    multiple: multiple,
    minimumInputLength: 3,
    ajax: {
      url: Spree.routes.products_api,
      dataType: 'json',
      data: function (params) {
        return {
          q: {
            name_or_master_sku_cont: params.term
          },
          m: 'OR',
          token: Spree.api_key
        }
      },
      processResults: function(data) {
        var products = data.products ? data.products : []
        var results = formatProductList(products)

        return {
          results: results
        }
      }
    },
    templateSelection: function(data, _container) {
      return data.text
    }
  })

  if (values) {
    addOptions(this, values)
  }
}

$(document).ready(function () {
  $('.product_picker').productAutocomplete()
})
