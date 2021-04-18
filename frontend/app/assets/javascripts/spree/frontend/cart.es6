//= require spree/api/storefront/cart

Spree.ready(() => {
  const buildEventTriggerObject = (dataset, quantity) => {
    if (!dataset || !quantity) return false

    // this is part of Spree Analytics Integration to properly track removal of items
    // https://github.com/spree-contrib/spree_analytics_trackers/blob/master/app/assets/javascripts/spree/frontend/remove_from_cart_analytics.js
    const triggerObject = {
      type: 'product_remove_from_cart',
      variant_sku: dataset.variantSku,
      variant_name: dataset.variantName,
      variant_price: dataset.variantPrice,
      variant_options: dataset.variantOptions,
      variant_quantity: quantity
    }

    return triggerObject
  }

  const getLineItemId = (element) => {
    if (element && element.hasAttribute('data-id')) {
      return element.getAttribute('data-id').replace('line_item_', '')
    }
  }
  const getLineItemInput = (lineItemId) => document.querySelector(`input[data-id='line_item_${lineItemId}']`)
  const getLineItemQuantity = (lineItemId) => parseInt(getLineItemInput(lineItemId).value, 10)
  const setLineItemQuantity = (lineItemId, newQuantity) => getLineItemInput(lineItemId).value = newQuantity

  const handleSetQuantity = (event, quantityChange = null, successCallback, failureCallback) => {
    event.preventDefault()

    const target = event.target
    const lineItemId = getLineItemId(target)
    const oldQuantity = getLineItemQuantity(lineItemId)

    let newQuantity = oldQuantity
    if (quantityChange) {
      newQuantity += quantityChange
    } else if (event.target.value) {
      newQuantity = parseInt(event.target.value)
    }

    Spree.showProgressBar()
    target.setAttribute('disabled', 'true')
    setLineItemQuantity(lineItemId, newQuantity)

    SpreeAPI.Storefront.setLineItemQuantity(
      lineItemId,
      newQuantity,
      response => successCallback(response),
      error => {
        failureCallback(error, target)
        setLineItemQuantity(lineItemId, oldQuantity)
      }
    )
  }

  const handleRemoveLineItem = (event, successCallback, failureCallback) => {
    event.preventDefault()

    // we need to check if click was recorded for the link element or SVG icon click inside the link
    let target = null

    if (event.target.hasAttribute('data-id')) {
      target = event.target
    } else {
      target = event.target.closest('[data-id]')
    }

    const lineItemId = getLineItemId(target)
    const quantity = getLineItemQuantity(lineItemId)

    Spree.showProgressBar()
    target.setAttribute('disabled', 'true')

    SpreeAPI.Storefront.removeLineItemFromCart(
      lineItemId,
      response => {
        if (target[0] && target[0].dataset && quantity) {
          target.trigger(buildEventTriggerObject(target[0].dataset, quantity))
        }
        successCallback(response)
      },
      error => failureCallback(error, target)
    )
  }

  // full page cart
  const formUpdateCart = document.getElementById('update-cart')
  if (formUpdateCart) {
    // success callback
    const handleCartApiSuccess = () => Spree.fetchCart(() => Turbolinks.visit())
    // failure
    const handleCartApiError = (error = null, target = null) => {
      if (target) target.removeAttribute('disabled')
      Spree.hideProgressBar()
      if (error) alert(error)
    }

    // handle remove line item from cart
    document.querySelectorAll('#update-cart .delete').forEach((target) => {
      target.addEventListener('click', (event) => handleRemoveLineItem(event, handleCartApiSuccess, handleCartApiError))
    })

    // handle quantity change
    document.querySelectorAll('#update-cart input.shopping-cart-item-quantity-input').forEach((target) => {
      target.addEventListener('change', (event) => handleSetQuantity(event, null, handleCartApiSuccess, handleCartApiError))
    })
    document.querySelectorAll('#update-cart .shopping-cart-item-quantity-decrease-btn').forEach((target) => {
      target.addEventListener('click', (event) => handleSetQuantity(event, -1, handleCartApiSuccess, handleCartApiError))
    })
    document.querySelectorAll('#update-cart .shopping-cart-item-quantity-increase-btn').forEach((target) => {
      target.addEventListener('click', (event) => handleSetQuantity(event, 1, handleCartApiSuccess, handleCartApiError))
    })

    formUpdateCart.addEventListener('submit', (event) => event.preventDefault())
  }

  if (!Spree.cartFetched) Spree.fetchCart()
})

// cart indicator
Spree.fetchCart = (successCallback = null) => {
  const cartIndicator = document.getElementById('link-to-cart')

  if (cartIndicator || successCallback) {
    fetch(Spree.localizedPathFor('cart_link'), {
      method: 'GET',
      credentials: 'same-origin'
    }).then((response) => {
      Spree.cartFetched = true
      response.text().then((html) => {
        if (cartIndicator) cartIndicator.innerHTML = html
        if (successCallback) successCallback()
      })
    })
  }
}

// when adding to cart we need to make sure that the cart exists
Spree.ensureCart = (successCallback) => {
  if (SpreeAPI.orderToken) {
    successCallback()
  } else {
    fetch(Spree.routes.ensure_cart, {
      method: 'POST',
      credentials: 'same-origin'
    }).then((response) => {
      switch (response.status) {
        case 200:
          response.json().then((json) => {
            SpreeAPI.orderToken = json.token
            successCallback()
          })
          break
      }
    })
  }
}
