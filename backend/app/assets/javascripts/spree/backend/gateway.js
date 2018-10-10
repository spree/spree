$(function () {
  var originalGtwyType = $('#gtwy-type').prop('value')
  $('div#gateway-settings-warning').hide()
  $('#gtwy-type').change(function () {
    // eslint-disable-next-line
    if ($('#gtwy-type').prop('value') == originalGtwyType) {
      $('div.gateway-settings').show()
      $('div#gateway-settings-warning').hide()
    } else {
      $('div.gateway-settings').hide()
      $('div#gateway-settings-warning').show()
    }
  })
})
