$j(function() {                                                                    
  var original_calc_type = $j('#calc-type').attr('value');
  $j('div#calculator-settings-warning').hide();
  $j('#calc-type').change(function() { 
    if ($j('#calc-type').attr('value') == original_calc_type) {
      $j('div.calculator-settings').show();
      $j('div#calculator-settings-warning').hide();
      $j('.calculator-settings input').removeAttr('disabled');
    } else {
      $j('div.calculator-settings').hide();
      $j('div#calculator-settings-warning').show();
      $j('.calculator-settings input').attr('disabled', 'disabled');
    }
  });
})
