// Allows you to use one autocomplete for several use cases with sensible defaults.

// REQUIRED ATTRIBUTES
// data-ac-name="products"        <- used for api search - Example: (taxons).
// data-ac-url="products_api_v2"  <- gets appended to const url - Example: (taxons_api_v2).

// OPTIONAL ATTRIBUTES
// data-ac-clear="boolean"                          <- true or false allows select2 clear.
// data-ac-multiple="boolean"                       <- true or false set multiple or single select
// data-ac-return-attr="pretty_name"                <- example shown returns taxon pretty_name
// data-ac-min-input="4"                            <- set a minimum input for search, default is 3.
// data-ac-search-query="name_or_master_sku_cont"   <- custom search query.

// can also be called directly as javastript.

document.addEventListener('DOMContentLoaded', function() {
  const select2Autocompletes = document.querySelectorAll('select.select2autocomplete')
  select2Autocompletes.forEach(element => buildParamsFromDataAttrs(element))
})

function buildParamsFromDataAttrs (element) {
  // Required Attributes
  const name = element.dataset.acName
  const url = element.dataset.acUrl

  // Optional Attributes
  const placeholder = element.dataset.acPlaceholder
  const clear = element.dataset.acClear
  const multiple = element.dataset.acMultiple
  const returnAttr = element.dataset.acReturnAttr
  const minimumInput = element.dataset.acMinInput
  const searchQuery = element.dataset.acSearchQuery

  $(element).select2Autocomplete({
    // Required Attributes
    data_attrbute_name: name,
    apiUrl: Spree.routes[url],

    // Optional Attributes
    placeholder: placeholder,
    allow_clear: clear,
    multiple: multiple,
    return_attribute: returnAttr,
    minimum_input: minimumInput,
    search_query: searchQuery
  })
}

$.fn.select2Autocomplete = function(params) {
  // Required params
  const apiUrl = params.apiUrl
  const dataAttrName = params.data_attrbute_name

  // Optional params
  const select2placeHolder = params.placeholder || `${Spree.translations.search}: ${dataAttrName}`
  const select2Multiple = params.multiple || false
  const select2allowClear = params.allow_clear || false
  const returnAttribute = params.return_attribute || 'name'
  const minimumInput = params.minimum_input || 3
  const searchQuery = params.search_query || 'name_i_cont'

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
            [searchQuery]: params.term
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
