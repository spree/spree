$(function () {
  var country_based = $('#country_based');
  var state_based = $('#state_based');
  country_based.click(show_country);
  state_based.click(show_state);
  if (country_based.is(':checked')) {
    show_country();
  } else if (state_based.is(':checked')) {
    show_state();
  } else {
    show_state();
    state_based.click();
  }
});

function show_country() {
  $('#state_members :input').each(function () {
    $(this).prop('disabled', true);
  });
  $('#state_members').hide();
  $('#zone_members :input').each(function () {
    $(this).prop('disabled', true);
  });
  $('#zone_members').hide();
  $('#country_members :input').each(function () {
    $(this).prop('disabled', false);
  });
  $('#country_members').show();
}

function show_state() {
  $('#country_members :input').each(function () {
    $(this).prop('disabled', true);
  });
  $('#country_members').hide();
  $('#zone_members :input').each(function () {
    $(this).prop('disabled', true);
  });
  $('#zone_members').hide();
  $('#state_members :input').each(function () {
    $(this).prop('disabled', false);
  });
  $('#state_members').show();
}
