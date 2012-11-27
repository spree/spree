$(function() {
  var calculator_select = $('select#calc_type')
  var original_calc_type = calculator_select.attr('value');
  $('div#calculator-settings-warning').hide();
  calculator_select.change(function() {
    if (calculator_select.attr('value') == original_calc_type) {
      $('div.calculator-settings').show();
      $('div#calculator-settings-warning').hide();
      $('.calculator-settings input').prop("disabled", false);
    } else {
      $('div.calculator-settings').hide();
      $('div#calculator-settings-warning').show();
      $('.calculator-settings input').prop("disabled", true);
    }
  });
})
