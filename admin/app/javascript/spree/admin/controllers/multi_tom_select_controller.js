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

    this.setValues(this.preloadedValuesValue)
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

    this.lastSelect = this.selectTargets[0]?.querySelector('select')
  }

  values() {
    return this.selectTargets
      .map((selectTarget) => selectTarget.querySelector('select'))
      .map((select) => select.options[select.selectedIndex].text)
      .filter((text) => text?.length > 0)
  }

  setValues() {
    this.reset()
    this.preloadedValuesValue.forEach((value) => this.addSelect(value))
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

  addSelect(value = null) {
    const newTomSelectTag = this.selectTemplateTarget.cloneNode(true)

    if (value) {
      newTomSelectTag.setAttribute('data-select-options-value', JSON.stringify(this.preloadedOptionsValue))
      newTomSelectTag.setAttribute('data-select-active-option-value', value.id)
    }

    newTomSelectTag.setAttribute('data-multi-tom-select-target', 'select')
    newTomSelectTag.setAttribute('data-controller', 'select')

    if (this.hasSelectTargets) {
      const lastSelect = this.selectTargets[this.selectTargets.length - 1]
      lastSelect.insertAdjacentElement('afterend', newTomSelectTag)
    } else {
      this.element.insertAdjacentElement('beforeend', newTomSelectTag)
    }

    this.lastSelect = newTomSelectTag.querySelector('select')
  }
}
