/* global Swal */
document.addEventListener('DOMContentLoaded', function() {
  const infoToggle = document.querySelectorAll('[data-show-info]')

  infoToggle.forEach(function(infoElem) {
    infoElem.addEventListener('click', function() {
      const alertType = infoElem.dataset.alertKind
      const alertTitle = infoElem.dataset.alertTitle
      const alertHtml = infoElem.dataset.alertHtml
      const alertMessage = infoElem.dataset.alertMessage

      showInfoAlert(alertType, alertTitle, alertMessage, alertHtml)
    })
  })
})

// eslint-disable-next-line no-unused-vars
function showInfoAlert(type = null, title = null, message = null, html = null) {
  const infoAlert = Swal.mixin({
    showConfirmButton: false,
    showCloseButton: true,
    timer: null,
    timerProgressBar: false,
    showClass: {
      popup: 'animate__animated animate__fadeInUp animate__faster'
    },
    hideClass: {
      popup: 'animate__animated animate__fadeOutDown animate__faster'
    }
  })

  infoAlert.fire({
    icon: type,
    title: title,
    text: message,
    html: html
  })
}
