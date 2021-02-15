/* global Cleave */

/* eslint-disable no-unused-vars */
function formatCardNumber (wrapperElement, cardNumberInput, cardTypeInput) {
  if (document.querySelector(wrapperElement)) {
      document.querySelectorAll(wrapperElement).forEach(function (cardPaymentSet) {

      if (cardNumberInput) {
        var targetNumberInput = cardPaymentSet.querySelector(cardNumberInput)
      } else {
        console.warn('Please identify your card number input using the second function argument')
      }

      if (cardTypeInput) {
        var targetCardType = cardPaymentSet.querySelector(cardTypeInput)
      } else {
        console.warn('Please identify your card type input using the third function argument')
      }

      if (cardNumberInput && cardTypeInput) {
        /* eslint-disable no-new */
        new Cleave(targetNumberInput, {
          creditCard: true,
          onCreditCardTypeChanged: function (type) {
            if (true) {}
            targetCardType.value = type
          }
        })
      }
    })
  } else {
    console.warn('Please identify the container element for the card input fields using the first function argument')
  }
}

/* eslint-disable no-unused-vars */
function formatCardExpiry (wrapperElement, cardExpiry) {
  if (document.querySelector(wrapperElement)) {
      document.querySelectorAll(wrapperElement).forEach(function (cardPaymentSet) {

      if (cardExpiry) {
        var targetCardExpiry = cardPaymentSet.querySelector(cardExpiry)
      } else {
        console.warn('Please identify your card expiry input field using the second argument in this function')
      }

      if (targetCardExpiry) {
        /* eslint-disable no-new */
        new Cleave(targetCardExpiry, {
          date: true,
          datePattern: ['m', Spree.translations.card_expire_year_format]
        })
      }
    })
  } else {
    console.warn('Please identify the container element for the card input fields using the first function argument')
  }
}

/* eslint-disable no-unused-vars */
function formatCardCode (wrapperElement, cardCode) {
  if (document.querySelector(wrapperElement)) {
      document.querySelectorAll(wrapperElement).forEach(function (cardPaymentSet) {

      if (cardCode) {
        var targetCardCode = cardPaymentSet.querySelector(cardCode)
      } else {
        console.warn('Please identify your card CVV code input field')
      }

      /* eslint-disable no-new */
      new Cleave(targetCardCode, {
        numericOnly: true,
        blocks: [3]
      })
    })
  } else {
    console.warn('Please identify the container element for the card input fields using the first function argument.')
  }
}
