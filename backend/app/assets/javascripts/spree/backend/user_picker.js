$.fn.userAutocomplete = function () {
  'use strict'

  console.warn('userAutocomplete is deprecated and will be removed in Spree 5.0')

  function formatUserList(values) {
    return values.map(function (obj) {
      return {
        id: obj.id,
        text: obj.attributes.email
      }
    })
  }

  this.select2({
    multiple: true,
    minimumInputLength: 1,
    ajax: {
      url: Spree.routes.users_api_v2,
      dataType: 'json',
      headers: Spree.apiV2Authentication(),
      data: function (params) {
        return {
          filter: {
            email_i_cont: params.term
          }
        }
      },
      processResults: function(data) {
        return {
          results: formatUserList(data.data)
        }
      }
    }
  })
}
