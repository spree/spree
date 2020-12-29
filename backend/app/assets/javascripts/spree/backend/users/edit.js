$(document).ready(function () {
  var useBilling = $('#user_use_billing')

  if (useBilling.is(':checked')) {
    $('#shipping').hide()
  }

  useBilling.change(function () {
    if (this.checked) {
      $('#shipping').hide()
      return $('#shipping input, #shipping select').prop('disabled', true)
    } else {
      $('#shipping').show()
      $('#shipping input, #shipping select').prop('disabled', false)
    }
  })
})
