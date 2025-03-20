import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['selectTemplate', 'select']

  static values = {
    preloadedValues: { type: Array, default: [] },
    preloadedOptions: { type: Array, default: [] }
  }

  connect() {
    this.element.reset = this.reset.bind(this)
    this.element.values = this.values.bind(this)
    this.element.setValues = this.setValues.bind(this)

    this.lastSelect = this.selectTargets[this.selectTargets.length - 1].querySelector('select')

    if (this.preloadedValuesValue.length > 0) {
      this.setValues(this.preloadedValuesValue)
    }
  }

  reset() {
    this.selectTargets.forEach((container, i) => {
      if (i > 0) {
        container.remove()
      } else {
        const select = container.querySelector('select')
        const tomSelect = select.tomselect

        if (tomSelect) {
          tomSelect.clear()
          tomSelect.clearOptions()
        }
      }
    })

    this.lastSelect = this.selectTargets[0]
  }

  values() {
    return this.selectTargets
      .map((selectTarget) => selectTarget.querySelector('select'))
      .map((select) => select.options[select.selectedIndex].text)
      .filter((text) => text?.length > 0)
  }

  setValues(values) {
    this.reset()

    values.forEach((value, i) => {
      if (i > 0) this.addSelect()

      const select = this.selectTargets[i].querySelector('select')
      const tomSelect = select.tomselect

      if (tomSelect) {
        tomSelect.clear()
        tomSelect.clearOptions()
        tomSelect.addOptions(this.preloadedOptionsValue)
        tomSelect.addItem(value)
      }
    })
  }

  handleSelect(event) {
    const ts = event.target.tomselect

    if (ts && ts.getValue().length > 0 && (this.lastSelect === event.target || this.selectTargets.length === 1)) {
      this.addSelect()
    }
  }

  handleKeyDown(event) {
    const ts = this.tomSelects.get(event.target)
    if (event.key === 'Backspace' && (!ts || ts.getValue().length === 0) && this.selectTargets.length > 1) {
      const inputContainer = event.target.closest('[data-multi-tom-select-target="select"]')
      this.removeSelect(inputContainer)
    }
  }

  removeSelect(container) {
    if (this.selectTargets.length > 1) {
      const input = container.querySelector('input, select')
      const ts = this.tomSelects.get(input)
      if (ts) {
        ts.destroy()
        this.tomSelects.delete(input)
      }
      container.remove()
    }
  }

  addSelect() {
    const newTomSelectTag = this.selectTemplateTarget.cloneNode(true)
    newTomSelectTag.setAttribute('data-multi-tom-select-target', 'select')
    newTomSelectTag.setAttribute('data-controller', 'select')

    const lastSelect = this.selectTargets[this.selectTargets.length - 1]
    lastSelect.insertAdjacentElement('afterend', newTomSelectTag)

    this.lastSelect = newTomSelectTag.querySelector('select')
  }
}
