import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone; // "for example: Europe/Warsaw"
    if (tz) {
      document.cookie = `tz=${encodeURIComponent(tz)}; Path=/; SameSite=Lax`;
    }
  }
}