/* global variantTemplate buildVariantData */

$(function() {
  var variantAutocompleteTemplate = $('#variant_autocomplete_template')
  if (variantAutocompleteTemplate.length > 0) {
    window.variantTemplate = Handlebars.compile(variantAutocompleteTemplate.text())
    window.variantStockTemplate = Handlebars.compile($('#variant_autocomplete_stock_template').text())
    window.variantLineItemTemplate = Handlebars.compile($('#variant_line_items_autocomplete_stock_template').text())
  }
})

function formatVariantResult(results) {
  if (results.loading) return results

  if (results.type === 'variant') {
    var options = results.attributes.options_text.split(',')

    return $(variantTemplate({
      options: options,
      variant: results.attributes
    }))
  }
}

function select2ResultsTemplate(variant) {
  if (variant.attributes) {
    if (variant.attributes.options_text) {
      return variant.attributes.name + ' (' + variant.attributes.options_text + ')'
    } else {
      return variant.attributes.name
    }
  }
}

$.fn.variantAutocomplete = function() {
  return this.select2({
    placeholder: Spree.translations.variant_placeholder,
    minimumInputLength: 3,
    ajax: {
      url: Spree.routes.variants_api_v2 + '?include=stock_items,images,stock_locations',
      headers: Spree.apiV2Authentication(),
      data: function(params) {
        var query = {
          filter: {
            product_name_or_sku_cont: params.term
          }
        }
        return query;
      },
      processResults: function(json) {
        var completeVariantData = buildVariantData(json)

        console.log(completeVariantData[0].attributes)

        window.variants = completeVariantData[0].attributes
        return { results: completeVariantData[0].attributes}
      }
    },
    templateResult: formatVariantResult,
    templateSelection: select2ResultsTemplate
  })
}
