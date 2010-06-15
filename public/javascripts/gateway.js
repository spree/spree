$j(function() {                                                                    
  var original_gtwy_type = $j('#gtwy-type').attr('value');
  $j('div#gateway-settings-warning').hide();
  $j('#gtwy-type').change(function() { 
    if ($j('#gtwy-type').attr('value') == original_gtwy_type) {
      $j('div.gateway-settings').show();
      $j('div#gateway-settings-warning').hide();
    } else {
      $j('div.gateway-settings').hide();
      $j('div#gateway-settings-warning').show();
    }
  });
})