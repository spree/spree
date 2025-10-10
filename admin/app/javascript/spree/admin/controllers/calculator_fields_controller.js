import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  replaceFields(event) {
    const selectedCalculator = event.target.value

    const calculatorName = selectedCalculator
      .split('::')
      .pop()
      .replace(/([A-Z])/g, '_$1')
      .toLowerCase()
      .replace(/^_/, '')

    const template = document.getElementById(`${calculatorName}_fields`)
    
    if (template) {
      this.containerTarget.innerHTML = template.innerHTML
    } else {
      console.error(`Template not found for calculator: ${selectedCalculator}`)
    }
  }
}
