$(function() {
  var original_calc_type = $('#calc-type').attr('value');
  $('div.calculator-settings-warning').hide();
  $('#calc-type').change(function() {
    if ($('#calc-type').attr('value') == original_calc_type) {
      $('div.calculator-settings').show();
      $('div.calculator-settings-warning').hide();
      $('.calculator-settings input').prop("disabled", false);
    } else {
      $('div.calculator-settings').hide();
      $('div.calculator-settings-warning').show();
      $('.calculator-settings input').prop("disabled", true);
    }
  });
})
