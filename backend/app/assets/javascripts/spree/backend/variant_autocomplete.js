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

function formatVariantResult(variant) {
  if (variant.loading) {
    return variant.text
  }

  if (variant['images'][0] !== undefined && variant['images'][0].mini_url !== undefined) {
    variant.image = variant.images[0].mini_url
  }
  return $(variantTemplate({
    variant: variant
  }))
}

$.fn.variantAutocomplete = function () {

  // deal with initSelection
  return this.select2({
    placeholder: Spree.translations.variant_placeholder,
    minimumInputLength: 3,
    quietMillis: 200,
    ajax: {
      url: Spree.url(Spree.routes.variants_api),
      dataType: 'json',
      data: function (params) {
        var query = {
          q: {
            search_by_product_name_or_sku: params.term
          },
          token: Spree.api_key
        }

        return query;
      },
      processResults: function(data) {
        window.variants = data['variants']
        return {
          results: data.variants
        }
      }
    },
    templateResult: formatVariantResult,
    templateSelection: function(variant) {
      if (!!variant.options_text) {
        return variant.name + '(' + variant.options_text + ')'
      } else {
        return variant.name
      }
    }
  })

}
