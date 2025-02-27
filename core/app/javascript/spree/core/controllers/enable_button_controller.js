import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"];
  static values = {
    allowBlank: { type: Boolean, default: false },
    disableWhenNotChanged: { type: Boolean, default: false },
  }

  connect() {
    this.buttonTarget.setAttribute("disabled", true);

    if (this.inputTargets.every((input) => input.value || input.checked || this.allowBlankValue) && !this.disableWhenNotChangedValue) {
      this.buttonTarget.removeAttribute("disabled");
    }

    this.inputTargets.forEach((input) => {
      input.addEventListener("input", (event) => this.handleChange(event));
    });
  }

  handleChange(event) {
    if (this.inputTargets.every((input) => event.target.value || event.target.checked || this.allowBlankValue)) {
      this.buttonTarget.removeAttribute("disabled");
    } else {
      this.buttonTarget.setAttribute("disabled", true);
    }
  }
}
