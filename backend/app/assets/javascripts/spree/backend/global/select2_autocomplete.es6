// SELECT2 AUTOCOMPLETE JS
// This JavaScript file allows Spree developers to set up Select2 autocomplete search
// using the API v2 by simply adding data attributes to a select element with the class: 'select2autocomplete'
// as shown here: <select class="select2autocomplete"></select>.

// REQUIRED ATTRIBUTES
// You must provide a URL for the API V2, use the format shown below.
// See the backend.js file for other API V2 URL's.
//
//  Example:
//  data-autocomplete-url-value="products_api_v2"

// OPTIONAL ATTRIBUTES
// These optional attributes have sensible defaults, you many not need to use them in many cases,
// but they do provide a powerful toolkit to refine your autocomplete search as required.
//
//  Examples:
//  data-autocomplete-placeholder-value="Seach Pages"    <- Sets the placeholder | DEFAULT is: 'Search'
//  data-autocomplete-clear-value="boolean"              <- Allow select2 to be cleared | DEFAULT is: false (no clear button)
//  data-autocomplete-multiple-value="boolean"           <- Multiple or Single select | DEFAULT is: false (single)
//  data-autocomplete-return-attr-value="pretty_name"    <- Return Attribute. | DEFAULT is: 'name'
//  data-autocomplete-min-input-value="4"                <- Minimum input for search | DEFAULT is: 3
//  data-autocomplete-search-query-value="title_i_cont"  <- Custom search query | DEFAULT is: 'name_i_cont'
//  data-autocomplete-custom-return-id-value="permalink" <- Return a custom attribute rather than the ID | DEFAULT: returns id
//
// SECOND HARD CODED FILTER - (OPTIONAL)
// Use a second hard coded search filter param and term if you require a little more curation
// than just all results returning, an example of this in use can be seen in the menu_item search for Pages,
// here we only want to retuen Pages that have linkable slugs, not homepages, and so we filter those using the
// data attributes shown below.
//
//  Examples:
//  data-autocomplete-additional-query-value="type_not_eq"                  <- Additional hard coded query | DEFAULT: null (not used)
//  data-autocomplete-additional-term-value="Spree::Cms::Pages::Homepage"   <- Additional hard coded term | DEFAULT: null (not used)

document.addEventListener('DOMContentLoaded', function() {
  const select2Autocompletes = document.querySelectorAll('select.select2autocomplete')
  select2Autocompletes.forEach(element => buildParamsFromDataAttrs(element))

  loadAutoCompleteParams()
})

// eslint-disable-next-line no-unused-vars
function loadAutoCompleteParams () {
  const select2Autocompletes = document.querySelectorAll('select[data-autocomplete-url-value]')
  select2Autocompletes.forEach(element => buildParamsFromDataAttrs(element))
}

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
    custom_return_id: element.dataset.autocompleteCustomReturnIdValue,

    // Hard coded additional filter for those edge cases.
    additional_query: element.dataset.autocompleteAdditionalQueryValue,
    additional_term: element.dataset.autocompleteAdditionalTermValue
  })
}

// Can also be called directly as javastript.
$.fn.select2Autocomplete = function(params) {
  // Required params
  const apiUrl = params.apiUrl || null

  // Optional Params
  const select2placeHolder = params.placeholder || Spree.translations.search
  const select2Multiple = params.multiple || false
  const select2allowClear = params.allow_clear || false
  const returnAttribute = params.return_attribute || 'name'
  const minimumInput = params.minimum_input || 3
  const searchQuery = params.search_query || 'name_i_cont'
  const customReturnId = params.custom_return_id || null
  const additionalQuery = params.additional_query || null
  const additionalTerm = params.additional_term || null

  function formatList(values) {
    if (customReturnId) {
      return values.map(function (obj) {
        return {
          id: obj.attributes[customReturnId],
          text: obj.attributes[returnAttribute]
        }
      })
    } else {
      return values.map(function (obj) {
        return {
          id: obj.id,
          text: obj.attributes[returnAttribute]
        }
      })
    }
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
