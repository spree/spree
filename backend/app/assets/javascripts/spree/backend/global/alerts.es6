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

  const alertEl = document.querySelectorAll('[data-alert-type]')

  if (!alertEl) return

  alertEl.forEach(function (elem) {
    const alertType = elem.dataset.alertType
    const alertMessage = elem.innerHTML

    if (alertType === 'expired') return

    show_flash(alertType, alertMessage)

    // Remove message once it has been shown,
    // it will be inserted back in the DOM as an expired-flash-alert
    elem.remove()
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

  appendToFlashAlertsContainer(sanitizedMessage, sanitizedType)
}

function appendToFlashAlertsContainer (message, type) {
  const parnetNode = document.querySelector('#FlashAlertsContainer')
  const node = document.createElement('SPAN');
  const textNode = document.createTextNode(message);

  parnetNode.innerHTML = ''

  node.classList.add('d-none', 'expired-flash-alert')
  node.setAttribute('data-alert-type', type);
  node.appendChild(textNode)

  parnetNode.appendChild(node);
}
