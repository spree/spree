$.fn.optionTypeAutocomplete = function () {
  'use strict'

  console.warn('optionTypeAutocomplete is deprecated and will be removed in Spree 5.0')

  this.select2({
    minimumInputLength: 2,
    multiple: true,
    ajax: {
      url: Spree.routes.option_types_api_v2,
      datatype: 'json',
      headers: Spree.apiV2Authentication(),
      data: function (params) {
        return {
          filter: {
            name_i_cont: params.term
          }
        }
      },
      processResults: function (data) {
        return formatSelect2Options(data)
      }
    }
  })
}
