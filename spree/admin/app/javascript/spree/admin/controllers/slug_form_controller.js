import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'name',
    'url',
  ]

  connect() {
    this.urlTouched = this.hasUrlTarget && this.urlTarget.value.length > 0
    if (this.hasUrlTarget) {
      this.urlTarget.addEventListener('input', () => { this.urlTouched = true })
    }
  }

  updateUrlFromName() {
    if (this.urlTouched) return
    const name = this.nameTarget.value
    // Mirrors ActiveSupport's +String#parameterize+: NFKD decompose, drop
    // combining marks (accents), lowercase, hyphenate the rest. Keeps the
    // legacy admin's auto-fill aligned with what +normalizes :code+ stores
    // server-side — without NFKD, "Café" rendered "caf-" instead of "cafe".
    const url = name
      .normalize('NFKD')
      .replace(/\p{M}/gu, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)+/g, '')
    this.urlTarget.value = url
  }
}
