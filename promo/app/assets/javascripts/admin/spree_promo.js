//= require admin/spree_core
//= require_tree .

function cleanUsers(data) {
  var users = $.map(data['users'], function(result) {
    return result['user']
  })
  return users;
}

$(document).ready(function() {
  if ($('user_picker').length > 0) {
    $('.user_picker').select2({
      minimumInputLength: 1,
      multiple: true,
      initSelection: function(element, callback) {
        $.get(Spree.routes.user_search, { ids: element.val() }, function(data) { 
          callback(cleanUsers(data))
        })
      },
      ajax: {
        url: Spree.routes.user_search,
        datatype: 'json',
        data: function(term, page) {
          return { q: term }
        },
        results: function(data, page) {
          return { results: cleanUsers(data) }
        }
      },
      formatResult: function(user) {
        return user.email;
      },
      formatSelection: function(user) {
        return user.email;
      }
    });
  }
})
