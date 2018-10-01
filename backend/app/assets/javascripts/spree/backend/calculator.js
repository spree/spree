$(function () {
  var calculatorSelect = $('select#calc_type')
  var originalCalcType = calculatorSelect.prop('value')
  $('.calculator-settings-warning').hide()
  calculatorSelect.change(function () {
    // eslint-disable-next-line eqeqeq
    if (calculatorSelect.prop('value') == originalCalcType) {
      $('div.calculator-settings').show()
      $('.calculator-settings-warning').hide()
      $('.calculator-settings').find('input,textarea').prop('disabled', false)
    } else {
      $('div.calculator-settings').hide()
      $('.calculator-settings-warning').show()
      $('.calculator-settings').find('input,texttarea').prop('disabled', true)
    }
  })
})
