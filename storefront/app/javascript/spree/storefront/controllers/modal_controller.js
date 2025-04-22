import { Modal } from 'tailwindcss-stimulus-components'

export default class extends Modal {
  static targets = ["container"]
  static values = {
    opened: Boolean
  }

  connect() {
    super.connect()

    if (this.openedValue) {
      super.open({preventDefault: () => {}, target: { blur: () => {}}})
    }
  }

  open(event) {
    super.open(event)

    const url = event.currentTarget.getAttribute('href')
    const container = this.containerTarget

    if (url && container) {
      container.src = url
    }
  }
}

