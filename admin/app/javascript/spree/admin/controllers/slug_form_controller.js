import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'name',
    'url',
  ]

  updateUrlFromName() {
    const name = this.nameTarget.value
    const url = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)+/g, '')
    this.urlTarget.value = url

    // TODO: do ajax call and check if url is available
    // if not, append a number to the end to make it unique
  }
}
