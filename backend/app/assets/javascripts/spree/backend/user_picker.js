$.fn.userAutocomplete = function () {
  'use strict'

  function formatUser (user) {
    return Select2.util.escapeMarkup(user.email)
  }

  function formatUserList(users) {
    var formatted_data = $.map(users, function (obj) {
      var item = { id: obj.id, text: obj.email }

      return item
    });

    return formatted_data
  }

  this.select2({
    multiple: true,
    minimumInputLength: 1,
    ajax: {
      url: Spree.routes.users_api,
      dataType: 'json',
      data: function (params) {
        var query = {
          q: {
            email_start: params.term
          },
          token: Spree.api_key
        }

        return query;
      },
      processResults: function(data) {
        var results = formatUserList(data.users)

        return {
          results: results
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
