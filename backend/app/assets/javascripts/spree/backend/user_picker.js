$.fn.userAutocomplete = function () {
  'use strict';

  this.select2({
    minimumInputLength: 1,
    multiple: true,
    initSelection: function (element, callback) {
      $.get(Spree.routes.user_search, {
        ids: element.val()
      }, function (data) {
        callback(data);
      });
    },
    ajax: {
      url: Spree.routes.user_search,
      datatype: 'json',
      data: function (term) {
        return {
          q: term
        };
      },
      results: function (data) {
        return {
          results: data
        };
      }
    },
    formatResult: function (user) {
      return user.email;
    },
    formatSelection: function (user) {
      return user.email;
    }
  });
};

$(document).ready(function () {
  $('.user_picker').userAutocomplete();
});