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
  $j('#create-zone button,#update-zone button').click(function() {
    $j('#ul-nested-country li input[name*=zoneable_type]').val('Country');
    $j('#ul-nested-state li input[name*=zoneable_type]').val('State');
    $j('#ul-nested-zone li input[name*=zoneable_type]').val('Zone');
  //  $j('#ul-nested-country li input').val('Country');
  //  $j('#ul-nested-state li input').val('State');
  //  $j('#ul-nested-zone li input').val('Zone');
  } );  
})   
                                                        
var show_country = function() {
  $j('#state_members :input').each(function() { $(this).disable(); })
  $j('#state_members').hide();
  $j('#zone_members :input').each(function() { $(this).disable(); })
  $j('#zone_members').hide();
  $j('#country_members :input').each(function() { $(this).enable(); })
  $j('#country_members').show();
};

var show_state = function() {
  $j('#country_members :input').each(function() { $(this).disable(); })
  $j('#country_members').hide();
  $j('#zone_members :input').each(function() { $(this).disable(); })
  $j('#zone_members').hide();
  $j('#state_members :input').each(function() { $(this).enable(); })
  $j('#state_members').show();
};

var show_zone = function() {
  $j('#state_members :input').each(function() { $(this).disable(); })
  $j('#state_members').hide();
  $j('#country_members :input').each(function() { $(this).disable(); })
  $j('#country_members').hide();
  $j('#zone_members :input').each(function() { $(this).enable(); })
  $j('#zone_members').show();
};

