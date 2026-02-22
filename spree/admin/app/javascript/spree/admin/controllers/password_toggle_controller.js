import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["unhide"]

  password(e) {
    if (this.unhideTarget.type === "password") {
      this.unhideTarget.type = "text"
    } else {
      this.unhideTarget.type = "password"
    }
  }
}

