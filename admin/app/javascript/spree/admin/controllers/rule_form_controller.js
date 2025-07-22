import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['value', 'template']

  replace(event) {
    const inputString = event.target.value;
    const parts = inputString.split("::");
    const lastPart = parts[parts.length - 1];

    const template = this.templateTargets.find((template) => template.id == `rule-form-template-${lastPart}`)

    if (template) {
      this.valueTarget.innerHTML = template.innerHTML
    }
  }
}
