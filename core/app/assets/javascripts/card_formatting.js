function validateCardElements () {

    // Formats card input
    if (document.querySelector('.cardNumber')) {
    document.querySelectorAll('.cardNumber').forEach(function (cardNumber) {
      new Cleave(cardNumber, {
        creditCard: true,
        onCreditCardTypeChanged: function (type) {
          $('.ccType').val(type)
        }
      })
    })
  }

  // Formats card expiry date
  if (document.querySelector('.cardExpiry')) {
    document.querySelectorAll('.cardExpiry').forEach(function (cardExpiry) {
      new Cleave(cardExpiry, {
        date: true,
        datePattern: ['m', Spree.translations.card_expire_year_format]
      })
    })
  }

  // Formats card CVV code
  if (document.querySelector('.cardCode')) {
    document.querySelectorAll('.cardCode').forEach(function (cardCode) {
      new Cleave(cardCode, {
        numericOnly: true,
        blocks: [3]
      })
    })
  }
}
