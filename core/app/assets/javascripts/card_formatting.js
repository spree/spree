/* global Cleave */

/* eslint-disable no-unused-vars */
function validateCardElements () {
  if (document.querySelector('.cardNumber')) {
    document.querySelectorAll('.cardNumber').forEach(function (cardNumber) {
      /* eslint-disable no-new */
      new Cleave(cardNumber, { creditCard: true, onCreditCardTypeChanged: function (type) { $('.ccType').val(type) } })
    })
  }

  if (document.querySelector('.cardExpiry')) {
    document.querySelectorAll('.cardExpiry').forEach(function (cardExpiry) {
      /* eslint-disable no-new */
      new Cleave(cardExpiry, { date: true, datePattern: ['m', Spree.translations.card_expire_year_format] })
    })
  }

  if (document.querySelector('.cardCode')) {
    document.querySelectorAll('.cardCode').forEach(function (cardCode) {
      /* eslint-disable no-new */
      new Cleave(cardCode, { numericOnly: true, blocks: [3] })
    })
  }
}
