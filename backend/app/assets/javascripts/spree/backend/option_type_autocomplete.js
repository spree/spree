  'use strict'
  function set_option_type_select(selector) {
    function formatOptionTypeResult (optionType) {
      return optionType.name
    }

    if ($(selector).length > 0) {
      $(selector).select2({
        minimumInputLength: 3,
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
        templateResult: formatOptionTypeResult,
        templateSelection: function (optionType) {
          return optionType.text
        }
      })
    }
  }

  $(document).ready(function () {
    set_option_type_select('#product_option_type_ids')
  })
