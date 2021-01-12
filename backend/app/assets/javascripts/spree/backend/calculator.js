$(function () {
  var calculatorSelect = $('select#calc_type')
  var originalCalcType = calculatorSelect.prop('value')
  $('.calculator-settings-warning').hide()
  calculatorSelect.change(function () {
    // eslint-disable-next-line
    if (calculatorSelect.prop('value') == originalCalcType) {
      $('div.calculator-settings').show()
      $('#shipping_method_calculator_attributes_preferred_currency').removeAttr('disabled')
      $('.calculator-settings-warning').hide()
      $('.calculator-settings').find('input, textarea').prop('disabled', false)
    } else {
      $('div.calculator-settings').hide()
      $('#shipping_method_calculator_attributes_preferred_currency').attr('disabled', 'disabled')
      $('.calculator-settings-warning').show()
      $('.calculator-settings').find('input, textarea').prop('disabled', true)
    }
  })
})
