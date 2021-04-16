//= require spree/frontend/coupon_manager
//= require spree/api/storefront/cart

Spree.ready(function ($) {
  var formUpdateCart = $('form#update-cart')

  function buildEventTriggerObject(dataset, quantity) {
    if (!dataset || !quantity) return false

    // this is part of Spree Analytics Integration to properly track removal of items
    // https://github.com/spree-contrib/spree_analytics_trackers/blob/master/app/assets/javascripts/spree/frontend/remove_from_cart_analytics.js
    var triggerObject = {
      type: 'product_remove_from_cart',
      variant_sku: dataset.variantSku,
      variant_name: dataset.variantName,
      variant_price: dataset.variantPrice,
      variant_options: dataset.variantOptions,
      variant_quantity: quantity
    }

    return triggerObject
  }

  function getLineItemId(element) {
    return $(element).attr('data-id').replace('line_item_', '')
  }

  function handleCartApiError(error, target) {
    if (target) target.attr('disabled', false)
    Spree.hideProgressBar()
    alert(error)
  }

  function handleCartApiSuccess() {
    window.location.reload()
  }

  function handleSetQuantity(lineItemId, quantity, input, target) {
    Spree.showProgressBar()
    target.attr('disabled', 'true')
    input.val(quantity)

    SpreeAPI.Storefront.setLineItemQuantity(
      lineItemId,
      quantity,
      function(response) { handleCartApiSuccess() },
      function(error) {
        handleCartApiError(error, target)
        input.val(quantity - 1) // revert to previous number
      }
    )
  }

  if (formUpdateCart.length) {
    var COUPON_CODE_ELEMENTS = {
      appliedCouponCodeField: formUpdateCart.find('#order_applied_coupon_code'),
      couponCodeField: formUpdateCart.find('#order_coupon_code'),
      couponStatus: formUpdateCart.find('#coupon_status'),
      couponButton: formUpdateCart.find('#shopping-cart-coupon-code-button'),
      removeCouponButton: formUpdateCart.find('#shopping-cart-remove-coupon-code-button')
    }

    // handle remove line item from cart
    formUpdateCart.find('a.delete').show().one('click', function (event) {
      event.preventDefault()

      var lineItemId = getLineItemId(this)
      var button = $(event.target)
      // FIXME: this selector madness need to go away...
      var quantityInputs = document.querySelector(`input[data-id='line_item_${lineItemId}']`)
      var quantity = $(quantityInputs).val()
      button.attr('disabled', true)

      Spree.showProgressBar()

      SpreeAPI.Storefront.removeLineItemFromCart(
        lineItemId,
        function(response) {
          handleCartApiSuccess()
          if (button[0] && button[0].dataset && quantity) {
            button.trigger(buildEventTriggerObject(button[0].dataset, quantity))
          }
        },
        function(error) { handleCartApiError(error, button) }
      )
    })

    // handle quantity change
    formUpdateCart.find('input.shopping-cart-item-quantity-input').on('change', function(event) {
      var lineItemId = getLineItemId(this)
      var input = $(event.target)
      var newValue = parseInt(input.val(), 10)
      handleSetQuantity(lineItemId, newValue, input, input)
    })
    formUpdateCart.find('button.shopping-cart-item-quantity-decrease-btn').off('click').on('click', function(event) {
      event.preventDefault()

      var lineItemId = getLineItemId(this)
      var button = $(event.target)
      var input = $("input[data-id='line_item_" + lineItemId + "']")
      var newValue = parseInt(input.val(), 10) - 1

      handleSetQuantity(lineItemId, newValue, input, button)
    })
    formUpdateCart.find('button.shopping-cart-item-quantity-increase-btn').off('click').on('click', function(event) {
      event.preventDefault()

      var lineItemId = getLineItemId(this)
      var button = $(event.target)
      var input = $("input[data-id='line_item_" + lineItemId + "']")
      var newValue = parseInt(input.val(), 10) + 1

      handleSetQuantity(lineItemId, newValue, input, button)
    })

    // handle coupon code apply
    COUPON_CODE_ELEMENTS.couponButton.off('click').on('click', function(event) {
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
    COUPON_CODE_ELEMENTS.removeCouponButton.off('click').on('click', function(event) {
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

Spree.fetchCart = function () {
  return $.ajax({
    url: Spree.localizedPathFor('cart_link')
  }).done(function (data) {
    Spree.cartFetched = true
    return $('#link-to-cart').html(data)
  })
}

Spree.ensureCart = function (successCallback) {
  if (SpreeAPI.orderToken) {
    successCallback()
  } else {
    fetch(Spree.routes.ensure_cart, {
      method: 'POST',
      credentials: 'same-origin'
    }).then(function (response) {
      switch (response.status) {
        case 200:
          response.json().then(function (json) {
            SpreeAPI.orderToken = json.token
            successCallback()
          })
          break
      }
    })
  }
}
