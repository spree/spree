$.fn.optionTypeAutocomplete = function () {
  'use strict'

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

$(document).ready(function () {
  $('#product_option_type_ids').optionTypeAutocomplete()
})
