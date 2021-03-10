$.fn.optionTypeAutocomplete = function () {
  'use strict'

  this.select2({
    minimumInputLength: 2,
    multiple: true,
    ajax: {
      url: Spree.routes.option_types_api,
      datatype: 'json',
      data: function (params) {
        var query = {
          q: {
            name_cont: params.term
          },
          token: Spree.api_key
        }

        return query
      },
      processResults: function (data) {
        return {
          results: data
        }
      }
    },
    templateResult: function (optionType) {
      return optionType.name
    },
    templateSelection: function (optionType) {
      return optionType.text
    }
  })
}

$(document).ready(function () {
  $('#product_option_type_ids').optionTypeAutocomplete()
})
