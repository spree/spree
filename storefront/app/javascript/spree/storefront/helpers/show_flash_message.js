const FLASH_CLASSES = {
  notice: ['alert-notice'],
  success: ['alert-success'],
  error: ['alert-error']
}

export default function showFlashMessage(messageText, type = 'notice') {
  const flashesContainer = document.querySelector('#flashes')
  const flashTemplate = document.querySelector('#flashMessage')

  // prevent alerts duplication
  flashesContainer.querySelectorAll('.flash-message').forEach(el => {
    if (el.textContent === messageText) {
      el.closest('[data-controller="alert"]').querySelector('[data-action="alert#close"]').click()
    }
  })

  const newFlash = flashTemplate.content.cloneNode(true)
  newFlash.querySelector('.flash-message').textContent = messageText
  newFlash
    .querySelector('[data-controller="alert"]')
    .classList.add(...FLASH_CLASSES[type])

  flashesContainer.appendChild(newFlash)
}
