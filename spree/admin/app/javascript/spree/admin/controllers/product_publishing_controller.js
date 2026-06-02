import { Controller } from '@hotwired/stimulus'

// Toggles the "Manage" channel-checkbox panel on the product Publishing card.
// Pairs with spree/admin/app/views/spree/admin/products/form/_publishing.html.erb.
export default class extends Controller {
  static targets = ['manage']

  toggleManage() {
    this.manageTarget.classList.toggle('d-none')
  }
}
