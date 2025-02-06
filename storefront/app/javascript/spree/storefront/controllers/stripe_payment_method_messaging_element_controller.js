import { Controller } from '@hotwired/stimulus'
import { loadStripe } from '@stripe/stripe-js/pure'

export default class extends Controller {
  static values = {
    apiKey: String,
    amount: Number,
    currency: String,
    country: String,
    fontFamily: String,
    textColor: String,
    accentColor: String
  }

  initialize() {
    const appearance = {
      theme: 'stripe',
      variables: {
        colorText: this.textColorValue,
        colorTextSecondary: this.accentColorValue,
        fontFamily: `${this.fontFamilyValue}, system-ui, sans-serif`,
        fontWeightMedium: 400,
      }
    }
    const options = {
      amount: this.amountValue,
      currency: this.currencyValue,
      paymentMethodTypes: ['klarna', 'afterpay_clearpay', 'affirm'],
      countryCode: this.countryValue
    }

    loadStripe(this.apiKeyValue).then((stripe) => {
      const elements = stripe.elements({ appearance })
      const PaymentMessageElement = elements.create('paymentMethodMessaging', options)
      PaymentMessageElement.mount(this.element)
    })
  }
}
