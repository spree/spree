$.fn.userAutocomplete = function () {
  'use strict'

  function formatUserList(values) {
    return values.map(function (obj) {
      return {
        id: obj.id,
        text: obj.email
      }
    })
  }

  this.select2({
    multiple: true,
    minimumInputLength: 1,
    ajax: {
      url: Spree.routes.users_api,
      dataType: 'json',
      data: function (params) {
        return {
          q: {
            email_start: params.term
          },
          token: Spree.api_key
        }
      },
      processResults: function(data) {
        return {
          results: formatUserList(data.users)
        }
      }
    },
    templateSelection: function (data) {
      return data.text
    }
  })
}

$(document).ready(function () {
  $('.user_picker').userAutocomplete()
})
