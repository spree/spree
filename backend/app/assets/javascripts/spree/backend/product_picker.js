$.fn.productAutocomplete = function (options) {
  'use strict'

  // Default options
  options = options || {}
  var multiple = typeof (options.multiple) !== 'undefined' ? options.multiple : true

  function formatProduct (product) {
    return Select2.util.escapeMarkup(product.name)
  }

  function formatProductList(products) {
    var formatted_data = $.map(products, function (obj) {
      var item = { id: obj.id, text: obj.name }
      return item
    });

    return formatted_data
  }

  this.select2({
    multiple: true,
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
    templateSelection: function(data, container) {
      return data.text
    }
  }).on("select2:unselect", function (e) {
    if($(this).select2('data').length == 0) {
      $('<input>').attr({ type: 'hidden', name: this.name, value: '', id: this.id }).appendTo('form.edit_promotion')
    }
  }).on('select2:select', function(e) {
    $('input#'+this.id).remove()
  })
}

$(document).ready(function () {
  $('.product_picker').productAutocomplete()
})
