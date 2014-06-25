// On page load
var replace_ids = function (s) {
  var new_id = new Date().getTime();
  return s.replace(/NEW_RECORD/g, new_id);
};

$(function () {
  'use strict';

  $('a[id*=nested]').on('click', function () {
    var template = $(this).prop('href').replace(/.*#/, '');
    var html = replace_ids(eval(template));
    $('#ul-' + $(this).prop('id')).append(html);
    update_remove_links();
  });
  update_remove_links();
});

var update_remove_links = function () {
  'use strict';

  $('.remove').on('click', function () {
    $(this).prevAll(':first').val(1);
    $(this).parent().hide();
    return false;
  });
};