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

  reset(addBlankSelect = true) {
    this.selectTargets.forEach((container) => container.remove())

    if (addBlankSelect)
      this.addSelect()
  }

  values() {
    return this.selectTargets
      .map((selectTarget) => selectTarget.querySelector('select'))
      .map((select) => select.options[select.selectedIndex])
      .filter((option) => option.value.length > 0)
      .map((option) => ({ text: option.text, value: option.value}))
  }

  setValues() {
    this.reset(false)
    this.preloadedValuesValue.forEach((value) => this.addSelect(value))

    if (this.selectTargets.length === this.preloadedValuesValue.length)
      this.addSelect()
  }

  handleSelect(event) {
    const ts = event.target.tomselect

    if (ts && ts.getValue().length > 0 && (this.lastSelect === event.target || this.selectTargets.length === 1)) {
      this.addSelect()
    } else if (ts && ts.getValue().length === 0 && this.selectTargets.length > 1) {
      const inputContainer = event.target.closest('[data-multi-tom-select-target="select"]')
      this.removeSelect(inputContainer)
    }
  }

  removeSelect(container) {
    if (this.selectTargets.length > 1) {
      const select = container.querySelector('select')
      select.tomselect?.destroy()
      container.remove()
    }
  }

  addSelect(value = null) {
    const newTomSelectTag = this.selectTemplateTarget.cloneNode(true)

    newTomSelectTag.setAttribute('data-select-options-value', JSON.stringify(this.preloadedOptionsValue))

    if (value)
      newTomSelectTag.setAttribute('data-select-active-option-value', value.id)

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
