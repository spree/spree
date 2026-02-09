import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "primaryColor",
    "textColor",
    "borderColor",
    "buttonTextColor",
    "backgroundColor"
  ]

  selectPalette(event) {
    this.primaryColorTarget.value = event.params.primaryColor
    this.textColorTarget.value = event.params.textColor
    this.borderColorTarget.value = event.params.borderColor
    this.buttonTextColorTarget.value = event.params.buttonTextColor
    this.backgroundColorTarget.value = event.params.backgroundColor

    // we need only one event to trigger the change
    this.primaryColorTarget.dispatchEvent(new InputEvent('change'))
  }
}
