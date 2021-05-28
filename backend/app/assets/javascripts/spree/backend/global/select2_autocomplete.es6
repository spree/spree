document.addEventListener('DOMContentLoaded', function() {
  const select2Autocompletes = document.querySelectorAll('select.select2autocomplete')
  select2Autocompletes.forEach(element => buildParamsFromDataAttrs(element))
})

// REQUIRED
// data-ac_name="products" <- used for api search.
// data-ac_url="products_api_v2" or data-ac_url="taxons_api_v2" <- gets appended to const to build url.

// OPTIONAL
// data-ac_clear="boolean" <- true or false allows select2 clear.
// data-ac_multiple="boolean" <- true or false set multiple or single select
// data-ac_return_attr="pretty_name" <- example shown returns taxon pretty_name
// data-ac_min_input="4" <- set a minimum input for search, default is 3.
// data-ac_search_query="name_or_master_sku_cont" <- custom search query.

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

// Allows you to use one autocomplete for several use cases with sensible defaults.
// Requires two params passing to work, the api URI, and the data attribute -> data_attrbute_name: 'products'
$.fn.select2Autocomplete = function(params) {
  // Required params
  const apiUrl = params.apiUrl
  const dataAttrName = params.data_attrbute_name

  // Custom params
  const select2placeHolder = params.placeholder || `${Spree.translations.search}: ${dataAttrName}` // Pass your own custom place holder as a string.
  const select2Multiple = params.multiple || false // Pass true to use multiple Select2.
  const select2allowClear = params.allow_clear || false // Pass true to use Allow Clear on the Select2, you will also need to set include_blank: true on the select el.
  const returnAttribute = params.return_attribute || 'name' // Pass a custom return attribute -> return_attribute: 'pretty_name'
  const minimumInput = params.minimum_input || 3 // Pass a custom minimum input
  const searchQuery = params.search_query || 'name_i_cont' // Pass a search query -> search_query: 'name_or_master_sku_cont'

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
