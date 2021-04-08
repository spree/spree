/* global Swal */

document.addEventListener('DOMContentLoaded', function() {
  const alertEl = document.querySelectorAll('[data-alert-type]')

  if (!alertEl) return

  alertEl.forEach(function (elem) {
    const alertType = elem.dataset.alertType
    const alertMessage = elem.innerHTML

    show_flash(alertType, alertMessage)
  })
})

// eslint-disable-next-line camelcase
function show_flash(type, message) {
  let sanitizedType = DOMPurify.sanitize(type)
  const sanitizedMessage = DOMPurify.sanitize(message)

  if (sanitizedType === 'notice') sanitizedType = 'info'

  // Set up Swal toast alert defaults
  const Toast = Swal.mixin({
    toast: true,
    position: 'bottom',
    showConfirmButton: false,
    showCloseButton: true,
    timer: 4500,
    timerProgressBar: false,
    showClass: {
      popup: 'animate__animated animate__fadeInUp animate__faster',
      backdrop: '-',
      icon: '-'
    },
    hideClass: {
      popup: 'animate__animated animate__fadeOutDown animate__faster',
      backdrop: '-',
      icon: '-'
    }
  })

  Toast.fire({
    icon: sanitizedType,
    title: sanitizedMessage
  })

  appendToFlashAlertsContainer(sanitizedMessage, sanitizedType)
}

function appendToFlashAlertsContainer (message, type) {
  if (type === 'info') type = 'notice'

  const parnetNode = document.querySelector('#FlashAlertsContainer')
  const node = document.createElement('SPAN');
  const textNode = document.createTextNode(message);

  // Only the most recent alert should be left in the #FlashAlertsContainer.
  parnetNode.innerHTML = ''

  node.classList.add('d-none')
  node.setAttribute('data-alert-type', type);
  node.appendChild(textNode)

  parnetNode.appendChild(node);
}
