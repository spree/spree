$(function () {
  var countryBased = $('#country_based')
  var stateBased = $('#state_based')
  countryBased.click(show_country)
  stateBased.click(show_state)
  if (countryBased.is(':checked')) {
    show_country()
  } else if (stateBased.is(':checked')) {
    show_state()
  } else {
    show_state()
    stateBased.click()
  }
})
// eslint-disable-next-line camelcase
function show_country () {
  $('#state_members :input').each(function () {
    $(this).prop('disabled', true)
  })
  $('#state_members').hide()
  $('#zone_members :input').each(function () {
    $(this).prop('disabled', true)
  })
  $('#zone_members').hide()
  $('#country_members :input').each(function () {
    $(this).prop('disabled', false)
  })
  $('#country_members').show()
}
// eslint-disable-next-line camelcase
function show_state () {
  $('#country_members :input').each(function () {
    $(this).prop('disabled', true)
  })
  $('#country_members').hide()
  $('#zone_members :input').each(function () {
    $(this).prop('disabled', true)
  })
  $('#zone_members').hide()
  $('#state_members :input').each(function () {
    $(this).prop('disabled', false)
  })
  $('#state_members').show()
}
