import { Dropdown } from 'tailwindcss-stimulus-components'

export default class extends Dropdown {
  hide(event) {
    let containsTarget = this.element.contains(event.target)
    if (this.element.getRootNode() instanceof ShadowRoot) {
      const trueTarget = event.composedPath()[0]
      containsTarget = this.element.contains(trueTarget)
    }
    if (event.target.nodeType && containsTarget === false && this.openValue) {
      this.openValue = false
    }
  }
}
