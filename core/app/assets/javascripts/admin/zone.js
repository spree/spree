$(function() {
  if ($('#country_based').is(':checked')) {
    show_country();
  } else if ($('#state_based').is(':checked')) {
    show_state();
  } else {
    show_zone();
  }
  $('#country_based').click(function() { show_country();} );
  $('#state_based').click(function() { show_state();} );
  $('#zone_based').click(function() { show_zone();} );
})

var show_country = function() {
  $('#state_members :input').each(function() { $(this).prop("disabled", true); })
  $('#state_members').hide();
  $('#zone_members :input').each(function() { $(this).prop("disabled", true); })
  $('#zone_members').hide();
  $('#country_members :input').each(function() { $(this).prop("disabled", false); })
  $('#country_members').show();
};

var show_state = function() {
  $('#country_members :input').each(function() { $(this).prop("disabled", true);
 })
  $('#country_members').hide();
  $('#zone_members :input').each(function() { $(this).prop("disabled", true);
 })
  $('#zone_members').hide();
  $('#state_members :input').each(function() { $(this).prop("disabled", false); })
  $('#state_members').show();
};

var show_zone = function() {
  $('#state_members :input').each(function() { $(this).prop("disabled", true);
 })
  $('#state_members').hide();
  $('#country_members :input').each(function() { $(this).prop("disabled", true);
 })
  $('#country_members').hide();
  $('#zone_members :input').each(function() { $(this).prop("disabled", false); })
  $('#zone_members').show();
};

