// this is a super simple controller to control the state of the add to wishlist icon state

import { Controller } from '@hotwired/stimulus'
import { post, destroy } from '@rails/request.js'
export default class extends Controller {
  static targets = ['add', 'remove']
  static values = {
    variantId: String,
    createWishlistPath: String,
    destroyWishlistPath: String
  }

  connect() {
    const wishedVariantIds = window.wishedVariantIds || [];
    const variantId = this.variantIdValue;

    if (wishedVariantIds.includes(variantId)) {
      this.showRemoveButton();
    } else {
      this.showAddButton();
    }
  }

  add = async (event) => {
    event.preventDefault()

    const body = new FormData()
    body.append('wished_item[variant_id]', this.variantIdValue)

    const headers = {}

    const response = await post(this.createWishlistPathValue, { 
      body: body,
      headers: headers,
      responseKind: 'turbo-stream'
    })
    if (response.ok) {
      this.showRemoveButton();
    } else {
      console.error('Error adding item to wishlist');
      window.alert('Error adding item to wishlist');
    }
  }

  remove = async (event) => {
    event.preventDefault()

    const headers = {}

    const response = await destroy(this.destroyWishlistPathValue, { 
      headers: headers,
      responseKind: 'turbo-stream'
    })
    if (response.ok) {
      this.showAddButton();
    } else {
      console.error('Error removing item from wishlist');
      window.alert('Error removing item from wishlist');
    }
  }

  showAddButton() {
    this.addTarget.classList.remove('hidden');
    this.removeTarget.classList.add('hidden');
  }

  showRemoveButton() {
    this.addTarget.classList.add('hidden');
    this.removeTarget.classList.remove('hidden');
  }
}
