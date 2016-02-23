$.fn.userAutocomplete = function () {
  'use strict';

  function formatUser(user) {
    return Select2.util.escapeMarkup(user.email);
  }

  this.select2({
    minimumInputLength: 1,
    multiple: true,
    initSelection: function (element, callback) {
      $.get(Spree.routes.user_search, {
        ids: element.val()
      }, function (data) {
        callback(data.users);
      });
    },
    ajax: {
      url: Spree.routes.user_search,
      datatype: 'json',
      data: function (term) {
        return {
          q: term,
          token: Spree.api_key
        };
      },
      results: function (data) {
        return {
          results: data.users
        };
      }
    },
    formatResult: formatUser,
    formatSelection: formatUser
  });
};

$(document).ready(function () {
  $('.user_picker').userAutocomplete();
});
