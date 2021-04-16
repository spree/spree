//= require spree/frontend/coupon_manager
//= require spree/api/storefront/cart

Spree.ready(function ($) {
  const formUpdateCart = $('form#update-cart')

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

  const handleCartApiError = (error, target) => {
    if (target) target.removeAttribute('disabled')
    Spree.hideProgressBar()
    alert(error)
  }

  const handleCartApiSuccess = () => Spree.fetchCart(() => Turbolinks.visit())

  const handleSetQuantity = (event, quantityChange = 0) => {
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
      _response => handleCartApiSuccess(),
      error => {
        handleCartApiError(error, target)
        setLineItemQuantity(lineItemId, oldQuantity)
      }
    )
  }

  const handleRemoveLineItem = (event) => {
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
      _response => {
        if (target[0] && target[0].dataset && quantity) {
          target.trigger(buildEventTriggerObject(target[0].dataset, quantity))
        }
        handleCartApiSuccess()
      },
      error => handleCartApiError(error, target)
    )
  }

  if (formUpdateCart.length) {
    const COUPON_CODE_ELEMENTS = {
      appliedCouponCodeField: formUpdateCart.find('#order_applied_coupon_code'),
      couponCodeField: formUpdateCart.find('#order_coupon_code'),
      couponStatus: formUpdateCart.find('#coupon_status'),
      couponButton: formUpdateCart.find('#shopping-cart-coupon-code-button'),
      removeCouponButton: formUpdateCart.find('#shopping-cart-remove-coupon-code-button')
    }

    // handle remove line item from cart
    document.querySelectorAll('#update-cart .delete').forEach((target) => target.addEventListener('click', (event) => handleRemoveLineItem(event)))

    // handle quantity change
    document.querySelectorAll('#update-cart input.shopping-cart-item-quantity-input').forEach((target) => target.addEventListener('change', (event) => handleSetQuantity(event)))
    document.querySelectorAll('#update-cart .shopping-cart-item-quantity-decrease-btn').forEach((target) => target.addEventListener('click', (event) => handleSetQuantity(event, -1)))
    document.querySelectorAll('#update-cart .shopping-cart-item-quantity-increase-btn').forEach((target) => target.addEventListener('click', (event) => handleSetQuantity(event, 1)))

    // handle coupon code apply
    COUPON_CODE_ELEMENTS.couponButton.off('click').on('click', (event) => {
      event.preventDefault()

      if ($.trim(COUPON_CODE_ELEMENTS.couponCodeField.val()).length > 0) {
        Spree.showProgressBar()

        if (new CouponManager(COUPON_CODE_ELEMENTS).applyCoupon()) {
          handleCartApiSuccess()
        } else {
          Spree.hideProgressBar()
        }
      }

      return false
    })

    // handle coupon code removal
    COUPON_CODE_ELEMENTS.removeCouponButton.off('click').on('click', (event) => {
      event.preventDefault()
      Spree.showProgressBar()

      if (new CouponManager(COUPON_CODE_ELEMENTS).removeCoupon()) {
        handleCartApiSuccess()
      } else {
        Spree.hideProgressBar()
      }
      return false
    })
  }

  // legacy submit action
  // will be removed in Spree 5.0
  formUpdateCart.submit(function (event) {
    if ($.trim(COUPON_CODE_ELEMENTS.couponCodeField.val()).length > 0) {
      // eslint-disable-next-line no-undef
      if (new CouponManager(COUPON_CODE_ELEMENTS).applyCoupon()) {
        this.submit()
        return true
      } else {
        event.preventDefault()
        return false
      }
    }
  })

  if (!Spree.cartFetched) Spree.fetchCart()
})

Spree.fetchCart = (successCallback) => {
  fetch(Spree.localizedPathFor('cart_link'), {
    method: 'GET',
    credentials: 'same-origin'
  }).then((response) => {
    Spree.cartFetched = true
    response.text().then((html) => {
      document.getElementById('link-to-cart').innerHTML = html
      if (successCallback) successCallback()
    })
  })
}

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
