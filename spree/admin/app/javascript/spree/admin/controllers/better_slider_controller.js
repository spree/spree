import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['currentValueLabel', 'rangeInput']
  static values = { labelForMin: String, unit: String }

  connect() {
    this.rangeInputTarget.addEventListener('input', this.updateCurrentValueLabel.bind(this))
    this.updateCurrentValueLabel()
  }

  updateCurrentValueLabel() {
    if (this.rangeInputTarget.value === this.rangeInputTarget.min && this.labelForMinValue.length) {
      this.currentValueLabelTarget.innerText = this.labelForMinValue
    } else {
      this.currentValueLabelTarget.innerText = this.rangeInputTarget.value + this.unitValue
    }
  }

  disconnect() {
    this.rangeInputTarget.removeEventListener('input', this.updateCurrentValueLabel.bind(this))
  }
}
