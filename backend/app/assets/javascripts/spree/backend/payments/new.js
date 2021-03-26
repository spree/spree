/* global Cleave */

$(document).ready(function () {
  if ($('#new_payment').length) {
    var cardCodeCleave;
    var updateCardCodeCleave = function (length) {
      if (cardCodeCleave) cardCodeCleave.destroy()

      cardCodeCleave = new Cleave('.cardCode', {
        numericOnly: true,
        blocks: [length]
      })
    }

    updateCardCodeCleave(3)

    /* eslint-disable no-new */
    new Cleave('.cardNumber', {
      creditCard: true,
      onCreditCardTypeChanged: function (type) {
        $('.ccType').val(type)

        if (type === 'amex') {
          updateCardCodeCleave(4)
        } else {
          updateCardCodeCleave(3)
        }
      }
    })
    /* eslint-disable no-new */
    new Cleave('.cardExpiry', {
      date: true,
      datePattern: ['m', 'Y']
    })

    $('.payment_methods_radios').click(
      function () {
        $('.payment-methods').hide()
        $('.payment-methods :input').prop('disabled', true)
        if (this.checked) {
          $('#payment_method_' + this.value + ' :input').prop('disabled', false)
          $('#payment_method_' + this.value).show()
        }
      }
    )

    $('.payment_methods_radios').each(
      function () {
        if (this.checked) {
          $('#payment_method_' + this.value + ' :input').prop('disabled', false)
          $('#payment_method_' + this.value).show()
        } else {
          $('#payment_method_' + this.value).hide()
          $('#payment_method_' + this.value + ' :input').prop('disabled', true)
        }

        if ($('#card_new' + this.value).is('*')) {
          $('#card_new' + this.value).radioControlsVisibilityOfElement('#card_form' + this.value)
        }
      }
    )
  }
})
