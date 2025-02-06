import { Controller } from '@hotwired/stimulus'
import { loadStripe } from '@stripe/stripe-js/pure'
import showFlashMessage from 'spree/storefront/helpers/show_flash_message'

export default class extends Controller {
  static values = {
    apiKey: String,
    orderToken: String,
    orderId: String,
    clientSecret: String,
    currency: String,
    country: String,
    amount: Number,
    availableCountries: Array,
    merchantOfRecordId: String,
    borderRadius: Number,
    height: Number,
    theme: String,
    maxRows: Number,
    maxColumns: Number,
    buttonWidth: Number,
    storeUrl: String,
    returnUrl: String,
  }

  static targets = ['container']

  connect() {
    this.paymentMethod = null
    this.initStripe()
    this.shippingRates = []
    this.currentShippingOptionId = null
  }

  initStripe() {
    if (typeof Stripe === 'undefined') {
      loadStripe(this.apiKeyValue).then((stripe) => {
        this.stripe = stripe
        this.prepareExpressCheckoutElement()
      })
    } else if (typeof this.stripe !== 'function') {
      this.stripe = Stripe(this.apiKeyValue)
      this.prepareExpressCheckoutElement()
    }
  }

  prepareExpressCheckoutElement() {
    this.elements = this.stripe.elements({
      mode: 'payment',
      currency: this.currencyValue,
      onBehalfOf: this.merchantOfRecordIdValue.length ? this.merchantOfRecordIdValue : undefined,
      amount: parseInt(this.amountValue),
      appearance: {
        theme: 'stripe',
        variables: {
          borderRadius: this.hasBorderRadiusValue ? `${this.borderRadiusValue}px` : undefined
        }
      },
      paymentMethodCreation: 'manual'
    })

    const prButton = this.elements.create('expressCheckout', {
      wallets: { applePay: 'always', googlePay: 'always' },
      buttonHeight: this.heightValue > 0 ? this.heightValue : undefined,
      buttonTheme: {
        applePay: this.themeValue.length ? this.themeValue : undefined,
        googlePay: this.themeValue.length ? this.themeValue : undefined
      },
      layout: {
        overflow: this.maxRowsValue > 0 ? 'auto' : 'never',
        maxColumns: this.maxColumnsValue > 0 ? this.maxColumnsValue : undefined,
        maxRows: this.maxRowsValue > 0 ? this.maxRowsValue : undefined
      },
      buttonType: {
        applePay: 'check-out',
        googlePay: 'checkout'
      },
      paymentMethodOrder: ['applePay', 'googlePay', 'link']
    })
    prButton.mount('#payment-request-button')

    prButton.on('ready', ({ availablePaymentMethods }) => {
      if (!availablePaymentMethods) {
        this.containerTarget.style.display = 'hidden'
        return
      }
      const availableMethodsCount = Object.keys(availablePaymentMethods).filter(
        (key) => availablePaymentMethods[key]
      ).length
      if (this.buttonWidthValue > 0) {
        this.containerTarget.style.setProperty(
          '--desktop-max-width',
          this.buttonWidthValue * availableMethodsCount + 'px'
        )
        this.containerTarget.classList.add('desktop-max-width')
      }
      window.parent?.postMessage({ enabledPaymentMethodsCount: availableMethodsCount }, '*')
    })
    prButton.on('click', (event) => {
      this.paymentMethod = event.expressPaymentType

      this.onQuickCheckoutStarted(event)

      event.resolve({
        emailRequired: true,
        shippingAddressRequired: true,
        allowedShippingCountries: this.availableCountriesValue,
        // If we want to collect shipping address then we need to provide at least one shipping option, it will be updated to the real ones in the `shippingaddresschange` event
        shippingRates: [{ id: 'loading', displayName: 'Loading...', amount: 0 }],
        lineItems: [
          { name: 'Subtotal', amount: 0 },
          { name: 'Shipping', amount: 0 },
          { name: 'Store credit', amount: 0 },
          { name: 'Discount', amount: 0 },
          { name: 'Tax', amount: 0 }
        ]
      })
    })
    prButton.on('shippingaddresschange', this.handleAddressChange.bind(this))
    prButton.on('shippingratechange', this.handleShippingOptionChange.bind(this))
    prButton.on('confirm', this.handleFinalizePayment.bind(this))
    prButton.on('cancel', this.handleCancelPayment.bind(this))
  }

  async handleAddressChange(ev) {
    // Perform server-side request to fetch shipping options
    // https://stripe.com/docs/js/payment_request/events/on_shipping_address_change#payment_request_on_shipping_address_change-handler-shippingAddress
    const orderUpdatePayload = {
      order: {
        ship_address_attributes: {
          // we need to use quick checkout option to skip first/last/street address validation
          // as at this point we don't receive this information as browsers do not share it with us
          quick_checkout: true,
          firstname: ev.name.split(' ')[0],
          lastname: ev.name.split(' ')[1],
          city: ev.address.city,
          zipcode: ev.address.postal_code,
          country_iso: ev.address.country,
          state_name: ev.address.state
        },
        bill_address_id: 'CLEAR' // we need to clear out the bill address to avoid order being pushed to confirm/complete state
      }
    }

    // 1st we need to persist the address to the order
    const saveAddressResponse = await fetch(`${this.storeUrlValue}/api/v2/storefront/checkout`, {
      method: 'PATCH',
      headers: {
        'X-Spree-Order-Token': this.orderTokenValue,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(orderUpdatePayload)
    })

    // 2nd we need to push the order to delivery state to generate shipping rates
    if (saveAddressResponse.status === 200) {
      // In case of any error here we have to allow user try again
      try {
        const response = await fetch(
          `${this.storeUrlValue}/api/v2/storefront/checkout/advance?state=delivery&include=shipments.shipping_rates,line_items.vendor`,
          {
            method: 'PATCH',
            headers: {
              'X-Spree-Order-Token': this.orderTokenValue,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({ quick_checkout: true, shipping_method_id: this.currentShippingOptionId })
          }
        )
        const newOrderResponse = await response.json()
        this.shippingRates = newOrderResponse.included.filter((item) => item.type === 'shipping_rate')

        if (this.shippingRates.length > 0) {
          this.elements.update({ amount: newOrderResponse.data.attributes.total_minus_store_credits_cents })
          const shippingRates = this.shippingOptions(this.shippingRates, newOrderResponse)
          // We need to select first shipping rate as default, because Apple Pay sometimes doesn't trigger `shippingratechange` event when the modal is opened
          this.currentShippingOptionId = String(shippingRates[0].id)

          ev.resolve({
            shippingRates: shippingRates,
            lineItems: this.buildLineItems(newOrderResponse)
          })
          return
        }
      } catch (error) {
        ev.reject()
        return
      }
    }
    ev.reject()
  }

  async handleShippingOptionChange(ev) {
    const { resolve, shippingRate, reject } = ev

    if (shippingRate) {
      const shippingRateId = String(shippingRate.id).replace(/_google_pay_\d+/, '')

      if (shippingRateId === 'standard') return resolve()
      if (shippingRateId === 'loading') return reject()

      this.currentShippingOptionId = shippingRateId

      const response = await fetch(`${this.storeUrlValue}/api/v2/storefront/checkout/select_shipping_method`, {
        method: 'PATCH',
        headers: {
          'X-Spree-Order-Token': this.orderTokenValue,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ shipping_method_id: shippingRateId })
      })

      if (response.status === 200) {
        const newOrderResponse = await response.json()

        this.elements.update({ amount: newOrderResponse.data.attributes.total_minus_store_credits_cents })
        resolve({ lineItems: this.buildLineItems(newOrderResponse) })
      } else {
        reject()
      }
    } else {
      reject()
    }
  }

  async handleFinalizePayment(ev) {
    let shippingRateId = (ev.shippingRate?.id || this.currentShippingOptionId)
    if (shippingRateId) {
      shippingRateId = String(shippingRateId).replace(/_google_pay_\d+/, '')
    }

    if (!shippingRateId || shippingRateId === 'loading') {
      ev.paymentFailed({ reason: 'invalid_shipping_address' })
      return
    }

    if (!this.validatePayment()) {
      ev.paymentFailed()
      return
    }

    // Confirm the PaymentIntent without handling potential next actions (yet).
    const { error: confirmError } = await this.elements.submit()

    if (confirmError) {
      if (confirmError.length > 0) {
        showFlashMessage(confirmError, 'error')
      }
      return
    }

    // we need to persist some information about the customer to move the order to the next state
    const orderUpdatePayload = {
      order: {
        email: ev.billingDetails.email,
        ship_address_attributes: {
          quick_checkout: true,
          firstname: ev.shippingAddress.name.split(' ')[0],
          lastname: ev.shippingAddress.name.split(' ')[1],
          address1: ev.shippingAddress.address.line1,
          address2: ev.shippingAddress.address.line2,
          city: ev.shippingAddress.address.city,
          zipcode: ev.shippingAddress.address.postal_code,
          country_iso: ev.shippingAddress.address.country,
          state_name: ev.shippingAddress.address.state,
          phone: ev.billingDetails.phone
        }
      },
      do_not_change_state: true
    }

    const updateResponse = await fetch(`${this.storeUrlValue}/api/v2/storefront/checkout`, {
      method: 'PATCH',
      headers: {
        'X-Spree-Order-Token': this.orderTokenValue,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(orderUpdatePayload)
    })

    if (updateResponse.status === 200) {
      const advanceResponse = await fetch(`${this.storeUrlValue}/api/v2/storefront/checkout/advance?state=payment`, {
        method: 'PATCH',
        headers: {
          'X-Spree-Order-Token': this.orderTokenValue,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ shipping_method_id: shippingRateId })
      })

      if (advanceResponse.status === 200) {
        try {
          const { error: paymentMethodError, paymentMethod } = await this.stripe.createPaymentMethod({
            elements: this.elements
          })

          if (paymentMethodError) {
            showFlashMessage(error, 'error')
            return
          }

          const { error } = await this.stripe.confirmPayment({
            clientSecret: this.clientSecretValue,
            confirmParams: {
              payment_method: paymentMethod.id,
              // Stripe will automatically add `payment_intent` and `payment_intent_client_secret` params
              return_url: this.returnUrlValue
            }
          })
          if (error) {
            if (error.length > 0) {
              showFlashMessage(error, 'error')
            }
            return
          }
        } catch (e) {
          console.log(e)
        }
      } else {
        ev.paymentFailed()
      }
    } else {
      ev.paymentFailed()
    }
  }

  async validatePayment() {
    const validationResponse = await fetch(
      `${this.storeUrlValue}/api/v2/storefront/checkout/validate_order_for_payment?skip_state=true`,
      {
        method: 'POST',
        headers: {
          'X-Spree-Order-Token': this.orderTokenValue,
          'Content-Type': 'application/json'
        }
      }
    )

    return validationResponse.status === 200
  }

  async handleCancelPayment(ev) {
    const orderUpdatePayload = {
      order: {
        ship_address_id: 'CLEAR',
        bill_address_id: 'CLEAR'
      }
    }

    // reset shipping method for some cases when user select paid shipping method then reload page
    // do not reset shipping method if we have only one or is multivendor order
    let defaultShippingMethodId = this.shippingRates[0]?.attributes?.shipping_method_id
    if (defaultShippingMethodId) {
      defaultShippingMethodId = String(defaultShippingMethodId)
    }

    if (this.shippingRates?.length > 1 && this.currentShippingOptionId !== defaultShippingMethodId) {
      // reset shipping choice
      await fetch(`${this.storeUrlValue}/api/v2/storefront/checkout/select_shipping_method`, {
        method: 'PATCH',
        headers: {
          'X-Spree-Order-Token': this.orderTokenValue,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ shipping_method_id: defaultShippingMethodId })
      })
    }

    // reset addresses
    await fetch(`${this.storeUrlValue}/api/v2/storefront/checkout`, {
      method: 'PATCH',
      headers: {
        'X-Spree-Order-Token': this.orderTokenValue,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(orderUpdatePayload)
    })

    this.currentShippingOptionId = null
  }

  shippingOptions(shippingRates, newOrderResponse) {
    return shippingRates.map((rate) => {
      let id = String(rate.attributes.shipping_method_id)
      if (this.paymentMethod === 'google_pay') {
        // We need to add some random data to the shipping rate to avoid weird issue with Google Pay, in which it clears the shipping rates when a new address is added
        id += `_google_pay_${Math.floor(Math.random() * 100)}`
      }
      return {
        id: id, // shipping rates can be refreshed and removed, shipping methods are more reliable
        displayName: rate.attributes.name,
        deliveryEstimate: rate.attributes.display_delivery_range || '',
        amount: parseInt(rate.attributes.final_price_cents)
      }
    })
  }

  buildLineItems(newOrderResponse) {
    return [
      { name: 'Subtotal', amount: newOrderResponse.data.attributes.subtotal_cents },
      { name: 'Shipping', amount: newOrderResponse.data.attributes.ship_total_cents },
      this.buildStoreCreditLine(newOrderResponse),
      this.buildDiscountLine(newOrderResponse),
      this.buildTaxLine(newOrderResponse)
    ].filter((i) => i)
  }

  buildStoreCreditLine(newOrderResponse) {
    const amount = newOrderResponse.data.attributes.store_credit_total_cents

    if (amount > 0) {
      return { name: 'Store credit', amount: -amount }
    }
  }

  buildDiscountLine(newOrderResponse) {
    const amount = newOrderResponse.data.attributes.promo_total_cents

    if (amount > 0) {
      return { name: 'Discount', amount: -amount }
    }
  }

  buildTaxLine(newOrderResponse) {
    const attributes = newOrderResponse.data.attributes
    const isTaxIncluded = parseInt(attributes.included_tax_total) > 0
    if (isTaxIncluded) return null

    const amount = attributes.tax_total_cents

    return { name: 'Tax', amount: amount }
  }

  onQuickCheckoutStarted(event) { }
}
