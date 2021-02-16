/* global Cleave */

/* eslint-disable no-unused-vars */
function formatCardNumber (wrapperElement, cardNumberInput, cardTypeInput) {
  if (!document.querySelector(wrapperElement)) return
  if (!cardNumberInput) return console.warn('Identify the card number input using the second function argument')
  if (!cardTypeInput) return console.warn('Identify the card type input using the third function argument')

  document.querySelectorAll(wrapperElement).forEach(function (cardPaymentSet) {
    var targetNumberInput = cardPaymentSet.querySelector(cardNumberInput)
    var targetCardType = cardPaymentSet.querySelector(cardTypeInput)

    /* eslint-disable no-new */
    new Cleave(targetNumberInput, {
      creditCard: true,
      onCreditCardTypeChanged: function (type) {
        targetCardType.value = type
        showCardType(cardPaymentSet, type)
      }
    })
  })
}

var selectedCardIcon = null

function showCardType (parent, type) {
  if (!parent) return
  if (!type) return

  if (selectedCardIcon) selectedCardIcon.classList.remove('active')

  selectedCardIcon = parent.querySelector(`.icon-${type}`)

  if (selectedCardIcon) selectedCardIcon.classList.add('active')
}

/* eslint-disable no-unused-vars */
function formatCardExpiry (wrapperElement, cardExpiry) {
  if (!document.querySelector(wrapperElement)) return
  if (!cardExpiry) return console.warn('Identify the expiry input field using the second function argument')

  document.querySelectorAll(wrapperElement).forEach(function (cardPaymentSet) {
    var targetCardExpiry = cardPaymentSet.querySelector(cardExpiry)

    /* eslint-disable no-new */
    new Cleave(targetCardExpiry, {
      date: true,
      datePattern: ['m', Spree.translations.card_expire_year_format]
    })
  })
}

/* eslint-disable no-unused-vars */
function formatCardCode (wrapperElement, cardCode) {
  if (!document.querySelector(wrapperElement)) return
  if (!cardCode) return console.warn('Identify the CVV code input field using the second function argument')

  document.querySelectorAll(wrapperElement).forEach(function (cardPaymentSet) {
    var targetCardCode = cardPaymentSet.querySelector(cardCode)

    /* eslint-disable no-new */
    new Cleave(targetCardCode, {
      numericOnly: true,
      blocks: [3]
    })
  })
}
