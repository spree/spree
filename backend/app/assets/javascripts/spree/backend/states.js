$(document).ready(function () {
  'use strict'

  if ($('#new_state_link').length) {
    $('#country').on('change', function () {
      var newStateLinkHref = $('#new_state_link').prop('href')
      var selectedCountryId = $('#country option:selected').prop('value')
      var newLink = newStateLinkHref.replace(/countries\/(\d+)/,
        'countries/' + selectedCountryId)
      $('#new_state_link').attr('href', newLink)
    })
  };
})
