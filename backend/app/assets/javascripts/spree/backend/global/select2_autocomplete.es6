// SELECT2 AUTOCOMPLETE JS
//  The JavaScript in this file allows Spree developers to set up Select2 autocomplete search
//  using the API v2 by simply adding data attributes to a select element.

// REQUIRED ATTRIBUTES
//  You must provide a URL for the API V2, use the format shown below. See backend.js for other API V2 URL's.
//  REQUIRED:
//  data-autocomplete-url-value="products_api_v2"

//  OPTIONAL:
//  data-autocomplete-placeholder-value="Seach Pages"     <- Sets the placeholder | DEFAULT is: 'Search'.
//  data-autocomplete-clear-value=boolean                 <- Allow select2 to be cleared | DEFAULT is: false (no clear button).
//  data-autocomplete-multiple-value=boolean              <- Multiple or Single select | DEFAULT is: false (single).
//  data-autocomplete-return-attr-value="pretty_name"     <- Return Attribute. | DEFAULT is: 'name'.
//  data-autocomplete-min-input-value="4"                 <- Minimum input for search | DEFAULT is: 3.
//  data-autocomplete-search-query-value="title_i_cont"   <- Custom search query | DEFAULT is: 'name_i_cont'.
//  data-autocomplete-custom-return-id-value="permalink"  <- Return a custom attribute | DEFAULT: returns id.
//  data-autocomplete-debug-mode-value=boolean            <- Turn on console loggin of data returned by the request.
//
//  Add your own custom URL params to the request as needed
//  EXAMPLE:
//  data-autocomplete-additional-url-params-value="filter[type_not_eq]=Spree::Cms::Pages::Homepage"

document.addEventListener('DOMContentLoaded', function() {
  loadAutoCompleteParams()
})

// eslint-disable-next-line no-unused-vars
function loadAutoCompleteParams() {
  const select2Autocompletes = document.querySelectorAll('select[data-autocomplete-url-value]')
  select2Autocompletes.forEach(element => buildParamsFromDataAttrs(element))
}

function buildParamsFromDataAttrs(element) {
  $(element).select2Autocomplete({
    apiUrl: Spree.routes[element.dataset.autocompleteUrlValue],
    placeholder: element.dataset.autocompletePlaceholderValue,
    allow_clear: element.dataset.autocompleteClearValue,
    multiple: element.dataset.autocompleteMultipleValue,
    return_attribute: element.dataset.autocompleteReturnAttrValue,
    minimum_input: element.dataset.autocompleteMinInputValue,
    search_query: element.dataset.autocompleteSearchQueryValue,
    custom_return_id: element.dataset.autocompleteCustomReturnIdValue,
    additional_url_params: element.dataset.autocompleteAdditionalUrlParamsValue,
    debug_mode: element.dataset.autocompleteDebugModeValue
  })
}

$.fn.select2Autocomplete = function(params) {
  let apiUrl = null
  let returnedFields

  const resourcePlural = params.apiUrl.match(/([^/]*)\/*$/)[1]
  const resourceSingular = resourcePlural.slice(0, -1)
  const select2placeHolder = params.placeholder || Spree.translations.search
  const select2Multiple = params.multiple || false
  const select2allowClear = params.allow_clear || false
  const returnAttribute = params.return_attribute || 'name'
  const minimumInput = params.minimum_input || 3
  const searchQuery = params.search_query || 'name_i_cont'
  const customReturnId = params.custom_return_id || null
  const additionalUrlParams = params.additional_url_params || null
  const DebugMode = params.debug_mode || null

  //
  // Set up a clean URL for sparseFields
  if (customReturnId == null) {
    returnedFields = returnAttribute
  } else {
    returnedFields = `${returnAttribute},${customReturnId}`
  }
  const sparseFields = `fields[${resourceSingular}]=${returnedFields}`

  //
  // Set up a clean URL for Additional URL Params
  if (additionalUrlParams != null) {
    // URL + Additional URL Params + Sparse Fields
    apiUrl = `${params.apiUrl}?${additionalUrlParams}&${sparseFields}`
  } else {
    // URL + Sparse Fields (the default response for a noraml Select2)
    apiUrl = `${params.apiUrl}?${sparseFields}`
  }

  if (DebugMode != null) console.log('Request URL:' + apiUrl)

  //
  // Format the returned values.
  function formatList(values) {
    if (customReturnId) {
      return values.map(function(obj) {
        return {
          id: obj.attributes[customReturnId],
          text: obj.attributes[returnAttribute]
        }
      })
    } else {
      return values.map(function(obj) {
        return {
          id: obj.id,
          text: obj.attributes[returnAttribute]
        }
      })
    }
  }

  //
  // Set-up Select2 and make AJAX request.
  this.select2({
    multiple: select2Multiple,
    allowClear: select2allowClear,
    placeholder: select2placeHolder,
    minimumInputLength: minimumInput,
    ajax: {
      url: apiUrl,
      headers: Spree.apiV2Authentication(),
      data: function(params) {
        return {
          filter: {
            [searchQuery]: params.term
          }
        }
      },
      processResults: function(json) {
        if (DebugMode != null) console.log(json)

        return {
          results: formatList(json.data)
        }
      }
    }
  })
}
