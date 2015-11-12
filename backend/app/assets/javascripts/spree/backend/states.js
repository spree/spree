$(document).ready(function () {
  'use strict';

  $('#country').on('change', function () {
    var new_state_link_href = $('#new_state_link a').prop('href');
    var selected_country_id = $('#country option:selected').prop('value');
    var new_link = new_state_link_href.replace(/countries\/(\d+)/,
      'countries/' + selected_country_id);
    $('#new_state_link a').attr('href', new_link);
  });
});
