$(document).ready(function () {
  'use strict'

  function formatOptionType (optionType) {
    return Select2.util.escapeMarkup(optionType.presentation + ' (' + optionType.name + ')')
  }

  if ($('#product_option_type_ids').length > 0) {
    $('#product_option_type_ids').select2({
      placeholder: Spree.translations.option_type_placeholder,
      multiple: true,
      initSelection: function (element, callback) {
        var url = Spree.url(Spree.routes.option_types_api, {
          ids: element.val(),
          token: Spree.api_key
        })
        return $.getJSON(url, null, function (data) {
          return callback(data)
        })
      },
      ajax: {
        url: Spree.routes.option_types_api,
        quietMillis: 200,
        datatype: 'json',
        data: function (term) {
          return {
            q: {
              name_cont: term
            },
            token: Spree.api_key
          }
        },
        results: function (data) {
          return {
            results: data
          }
        }
      },
      formatResult: formatOptionType,
      formatSelection: formatOptionType
    })
  }
})
