import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "addField", "fieldsContainer", "fieldTemplate"]

  connect() {
    this.fieldsCount = this.fieldTargets.length
  }

  addField(e) {
    e.preventDefault()

    const template = this.fieldTemplateTarget.innerHTML.replace(/INDEX/g, this.fieldsCount)
    this.fieldsContainerTarget.insertAdjacentHTML("beforeend", template)
  }

  removeField(e) {
    e.preventDefault()

    const field = e.target.closest(`[data-${this.identifier}-target='field']`)
    field.remove()
  }
}
