$j(function() { 
  if ($j('#country_based').attr('checked')) {
    show_country();
  } else if ($j('#state_based').attr('checked')) {
    show_state();
  } else {        
    show_zone();
  }
  $j('#country_based').click(function() { show_country();} );
  $j('#state_based').click(function() { show_state();} );
  $j('#zone_based').click(function() { show_zone();} ); 
})   
                                                        
var show_country = function() {
  $j('#state_members :input').each(function() { $(this).attr('disabled','disabled'); })
  $j('#state_members').hide();
  $j('#zone_members :input').each(function() { $(this).attr('disabled','disabled'); })
  $j('#zone_members').hide();
  $j('#country_members :input').each(function() { $(this).removeAttr('disabled'); })
  $j('#country_members').show();
};

var show_state = function() {
  $j('#country_members :input').each(function() { $(this).attr('disabled','disabled'); })
  $j('#country_members').hide();
  $j('#zone_members :input').each(function() { $(this).attr('disabled','disabled'); })
  $j('#zone_members').hide();
  $j('#state_members :input').each(function() { $(this).removeAttr('disabled'); })
  $j('#state_members').show();
};

var show_zone = function() {
  $j('#state_members :input').each(function() { $(this).attr('disabled','disabled'); })
  $j('#state_members').hide();
  $j('#country_members :input').each(function() { $(this).attr('disabled','disabled'); })
  $j('#country_members').hide();
  $j('#zone_members :input').each(function() { $(this).removeAttr('disabled'); })
  $j('#zone_members').show();
};