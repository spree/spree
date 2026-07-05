import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String
  }

  connect() {
    // Controller is ready
  }

  // This method can be used to handle custom list interactions
  // Currently, form submission is handled by the form's native behavior
  // with Turbo, so this is mainly a placeholder for future enhancements

  refresh() {
    // Reload the current page with Turbo
    Turbo.visit(window.location.href)
  }
}
