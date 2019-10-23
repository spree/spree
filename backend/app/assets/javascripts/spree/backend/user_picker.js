$.fn.userAutocomplete = function () {
  'use strict'

  function formatUser (user) {
    return Select2.util.escapeMarkup(user.email)
  }

  this.select2({
    minimumInputLength: 1,
    multiple: true,
    initSelection: function (element, callback) {
      $.get(Spree.routes.users_api, {
        ids: element.val(),
        token: Spree.api_key
      }, function (data) {
        callback(data.users)
      })
    },
    ajax: {
      url: Spree.routes.users_api,
      datatype: 'json',
      data: function (term) {
        return {
          q: {
            email_cont: term
          },
          token: Spree.api_key
        }
      },
      results: function (data) {
        return {
          results: data.users
        }
      }
    },
    formatResult: formatUser,
    formatSelection: formatUser
  })
}

$(document).ready(function () {
  $('.user_picker').userAutocomplete()
})
