/* global variantTemplate */
// variant autocompletion
$(function () {
  var variantAutocompleteTemplate = $('#variant_autocomplete_template')
  if (variantAutocompleteTemplate.length > 0) {
    window.variantTemplate = Handlebars.compile(variantAutocompleteTemplate.text())
    window.variantStockTemplate = Handlebars.compile($('#variant_autocomplete_stock_template').text())
    window.variantLineItemTemplate = Handlebars.compile($('#variant_line_items_autocomplete_stock_template').text())
  }
})

function formatVariantResult (variant) {
  if (variant['images'][0] !== undefined && variant['images'][0].mini_url !== undefined) {
    variant.image = variant.images[0].mini_url
  }
  return variantTemplate({
    variant: variant
  })
}

$.fn.variantAutocomplete = function () {
  return this.select2({
    placeholder: Spree.translations.variant_placeholder,
    minimumInputLength: 3,
    initSelection: function (element, callback) {
      return $.get(Spree.routes.variants_api + '/' + element.val(), {
        token: Spree.api_key
      }).done(function (data) {
        return callback(data)
      })
    },
    ajax: {
      url: Spree.url(Spree.routes.variants_api),
      quietMillis: 200,
      datatype: 'json',
      data: function (term) {
        return {
          q: {
            product_name_or_sku_cont: term
          },
          token: Spree.api_key
        }
      },
      results: function (data) {
        window.variants = data['variants']
        return {
          results: data['variants']
        }
      }
    },
    formatResult: formatVariantResult,
    formatSelection: function (variant) {
      // eslint-disable-next-line no-extra-boolean-cast
      if (!!variant.options_text) {
        return Select2.util.escapeMarkup(variant.name + '(' + variant.options_text + ')')
      } else {
        return Select2.util.escapeMarkup(variant.name)
      }
    }
  })
}
