$.fn.productAutocomplete = function (options) {
  'use strict'

  // Default options
  options = options || {}
  var multiple = typeof (options.multiple) !== 'undefined' ? options.multiple : true
  var values = typeof (options.values) !== 'undefined' ? options.values : null

  function addOptions(select, values) {
    $.ajax({
      url: Spree.routes.products_api_v2 ,
      dataType: 'json',
      headers: Spree.apiV2Authentication(),
      data: {
        filter: {
          id_in: values
        }
      }
    }).then(function (data) {
      select.addSelect2Options(data.products)
    })
  }

  this.select2({
    multiple: multiple,
    minimumInputLength: 3,
    ajax: {
      url: Spree.routes.products_api_v2,
      dataType: 'json',
      headers: Spree.apiV2Authentication(),
      data: function (params) {
        return {
          filter: {
            name_or_master_sku_cont: params.term
          }
        }
      },
      processResults: function(data) {
        return formatSelect2Options(data)
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
