import { Modal } from 'tailwindcss-stimulus-components'

export default class extends Modal {
  static values = {
    opened: Boolean
  }

  connect() {
    super.connect()

    if (this.openedValue) {
      super.open({preventDefault: () => {}, target: { blur: () => {}}})
    }
  }
}
