import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input']

  change({ params: { tab } }) {
    this.inputTarget.value = tab
  }
}
