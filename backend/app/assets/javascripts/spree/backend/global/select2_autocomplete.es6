// Allows you to use one autocomplete for sevral use cases with sensible defaults.
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
