import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input']

  static values = {
    preloadedValues: Array
  }

  connect() {
    this.element.reset = this.reset.bind(this)
    this.element.values = this.values.bind(this)
    this.element.setValues = this.setValues.bind(this)
    this.lastInput = null
    this.setValues(this.preloadedValuesValue)
  }

  reset() {
    this.inputTargets.forEach((container, i) => {
      if (i > 0) {
        container.remove()
      } else {
        const input = container.querySelector('input')
        input.value = ''
      }
    })
    this.lastInput = this.inputTargets[0].querySelector('input')
  }

  values() {
    return this.inputTargets
      .map((c) => c.querySelector('input'))
      .map((input) => input?.value)
      .filter((value) => value?.length > 0)
  }

  setValues(values) {
    this.reset()
    values.forEach((value, i) => {
      if (i > 0) {
        this.addInput()
      }
      this.inputTargets[i].querySelector('input').value = value
    })
    if (this.inputTargets.length === values.length) this.addInput()
  }

  handleInput(event) {
    if (event.target.value.length > 0 && (this.lastInput === event.target || this.inputTargets.length === 1)) {
      this.addInput()
    }
  }

  handleKeyDown(event) {
    if (event.key === 'Backspace' && event.target.value.length === 0 && this.inputTargets.length > 1) {
      const inputContainer = event.target.closest('[data-multi-input-target="input"]')
      this.removeInput(inputContainer)
    }
  }

  removeInput(input) {
    if (this.inputTargets.length > 1) {
      input.remove()
    }
  }

  addInput() {
    const inputToClone = this.inputTargets[this.inputTargets.length - 1]
    const newInputTemplate = inputToClone.cloneNode(true)
    newInputTemplate.querySelector('input').value = ''
    const newInputContainer = inputToClone.insertAdjacentElement('afterend', newInputTemplate)
    const newInput = newInputContainer.querySelector('input')
    this.lastInput = newInput
  }
}
