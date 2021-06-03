// Allows you to use one autocomplete for several use cases with sensible defaults.

// REQUIRED ATTRIBUTES
// data-autocomplete-url-value="products_api_v2"  <- gets appended to const url - Example: (taxons_api_v2).

// OPTIONAL ATTRIBUTES
// data-autocomplete-clear-value="boolean"                          <- true or false allows select2 clear.
// data-autocomplete-multiple-value="boolean"                       <- true or false set multiple or single select
// data-autocomplete-return-attr-value="pretty_name"                <- example shown returns taxon pretty_name
// data-autocomplete-min-input-value="4"                            <- set a minimum input for search, default is 3.
// data-autocomplete-search-query-value="name_or_master_sku_cont"   <- custom search query.

// can also be called directly as javastript.

document.addEventListener('DOMContentLoaded', function() {
  const select2Autocompletes = document.querySelectorAll('select.select2autocomplete')
  select2Autocompletes.forEach(element => buildParamsFromDataAttrs(element))
})

function buildParamsFromDataAttrs (element) {
  $(element).select2Autocomplete({
    // Required Attributes
    apiUrl: Spree.routes[element.dataset.autocompleteUrlValue],

    // Optional Attributes
    placeholder: element.dataset.autocompletePlaceholderValue,
    allow_clear: element.dataset.autocompleteClearValue,
    multiple: element.dataset.autocompleteMultipleValue,
    return_attribute: element.dataset.autocompleteReturnAttrValue,
    minimum_input: element.dataset.autocompleteMinInputValue,
    search_query: element.dataset.autocompleteSearchQueryValue,

    // hard coded additional filter for those edge cases.
    additional_query: element.dataset.autocompleteAdditionalQueryValue,
    additional_term: element.dataset.autocompleteAdditionalTermValue
  })
}

$.fn.select2Autocomplete = function(params) {
  // Required params
  const apiUrl = params.apiUrl

  // Optional params
  const select2placeHolder = params.placeholder || Spree.translations.search
  const select2Multiple = params.multiple || false
  const select2allowClear = params.allow_clear || false
  const returnAttribute = params.return_attribute || 'name'
  const minimumInput = params.minimum_input || 3
  const searchQuery = params.search_query || 'name_i_cont'

  const additionalQuery = params.additional_query || null
  const additionalTerm = params.additional_term || null

  function formatList(values) {
    return values.map(function (obj) {
      return {
        id: obj.id,
        text: obj.attributes[returnAttribute]
      }
    })
  }

  this.select2({
    multiple: select2Multiple,
    allowClear: select2allowClear,
    placeholder: select2placeHolder,
    minimumInputLength: minimumInput,
    ajax: {
      url: apiUrl,
      headers: Spree.apiV2Authentication(),
      data: function (params) {
        return {
          filter: {
            [searchQuery]: params.term,
            [additionalQuery]: additionalTerm
          }
        }
      },
      processResults: function(json) {
        return {
          results: formatList(json.data)
        }
      }
    }
  })
}
