$(function () {
  var countryBased = $('#country_based')
  var stateBased = $('#state_based')
  countryBased.click(displayCountry)
  stateBased.click(displayState)
  if (countryBased.is(':checked')) {
    displayCountry()
  } else if (stateBased.is(':checked')) {
    displayState()
  } else {
    displayState()
    stateBased.click()
  }
})

function displayCountry () {
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

function displayState () {
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
