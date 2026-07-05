// Custom Turbo confirm dialog
// Replaces browser native confirm() with a styled dialog

export function initTurboConfirm() {
  const dialog = document.getElementById("turbo-confirm-dialog")
  const messageElement = document.getElementById("turbo-confirm-message")
  const confirmButton = document.getElementById("turbo-confirm-button")

  if (!dialog || !messageElement || !confirmButton) return

  Turbo.config.forms.confirm = (message, element, submitter) => {
    messageElement.textContent = message

    // Allow custom button text via data-turbo-confirm-button attribute
    const buttonText = submitter?.dataset.turboConfirmButton || element?.dataset.turboConfirmButton || "Confirm"
    confirmButton.textContent = buttonText

    // Allow custom button class via data-turbo-confirm-button-class attribute
    const buttonClass = submitter?.dataset.turboConfirmButtonClass || element?.dataset.turboConfirmButtonClass
    if (buttonClass) {
      confirmButton.className = `btn ${buttonClass}`
    } else {
      confirmButton.className = "btn btn-primary"
    }

    dialog.showModal()

    return new Promise((resolve) => {
      dialog.addEventListener("close", () => {
        resolve(dialog.returnValue === "confirm")
      }, { once: true })
    })
  }
}

// Initialize on DOMContentLoaded and turbo:load
document.addEventListener("DOMContentLoaded", initTurboConfirm)
document.addEventListener("turbo:load", initTurboConfirm)
