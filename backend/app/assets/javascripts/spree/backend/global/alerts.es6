// Triggers alert if required on DOMContentLoaded.
document.addEventListener('DOMContentLoaded', function() {
  var element = document.querySelector('.flash-alert')

  if (element) {
    handleAlert(element)
  }
})

// Triggers alerts when requested by javascript.
// eslint-disable-next-line camelcase, no-unused-vars
function show_flash(type, message) {
  var cleanMessage = DOMPurify.sanitize(message)
  var existingAlert = document.querySelector('.flash-alert')

  if (existingAlert) {
    existingAlert.remove()
  }

  var flashDiv = $('.alert-' + type)
  if (flashDiv.length === 0) {
    flashDiv = $('<div class="d-flex justify-content-center position-fixed flash-alert">' +
      '<div class="alert alert-' + type + ' mx-2">' + cleanMessage + '</div></div>')

    $('body').append(flashDiv)

    var ajaxFlashNotfication = document.querySelector('.flash-alert')
    handleAlert(ajaxFlashNotfication)
  }
}

function handleAlert(element) {
  element.classList.add('animate__animated', 'animate__bounceInUp')
  element.addEventListener('animationend', function() {
    element.classList.remove('animate__bounceInUp')
    element.classList.add('animate__fadeOutDownBig', 'animate__delay-3s')
  })
}
