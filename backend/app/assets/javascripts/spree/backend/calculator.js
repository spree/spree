$(function() {
  var calculator_select = $('select#calc_type')
  var original_calc_type = calculator_select.prop('value');
  $('.calculator-settings-warning').hide();
  calculator_select.change(function() {
    if (calculator_select.prop('value') == original_calc_type) {
      $('div.calculator-settings').show();
      $('.calculator-settings-warning').hide();
      $('.calculator-settings').find('input,textarea').prop("disabled", false);
    } else {
      $('div.calculator-settings').hide();
      $('.calculator-settings-warning').show();
      $('.calculator-settings').find('input,texttarea').prop("disabled", true);
    }
  });
})
