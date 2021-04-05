/* global Noty */

document.addEventListener('DOMContentLoaded', function() {
  // Set up Noty alert defaults
  Noty.overrideDefaults({
    layout: 'bottomCenter',
    theme: 'bootstrap-v4',
    timeout: '3000',
    progressBar: false,
    closeWith: ['button'],
    animation: {
      open: 'animate__animated animate__fadeInUp animate__faster',
      close: 'animate__animated animate__fadeOutDown animate__faster'
    }
  })

  // Find all DIV elements with the attribute 'data-flash-alert' if one or more are
  // present in the DOM on page load we de-construct the data for each instance
  // and pass the date to the 'flash_alert()' function.
  const alertEl = document.querySelectorAll('[data-flash-alert]')

  if (!alertEl) return

  alertEl.forEach(function (elem) {
    const alertType = elem.dataset.alertType
    const alertMessage = elem.innerHTML

    show_flash(alertType, alertMessage)
  })
})

// eslint-disable-next-line camelcase
function show_flash(type, message) {
  const sanitizedType = DOMPurify.sanitize(type)
  const sanitizedMessage = DOMPurify.sanitize(message)

  new Noty({
    type: sanitizedType,
    text: sanitizedMessage
  }).show()
}
