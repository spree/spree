/* global Cleave */

$(document).ready(function () {
  var CARD_NUMBER_SELECT = '.cardNumber'
  var CARD_CODE_SELECT = '.cardCode'
  var CARD_EXPIRATION_SELECT = '.cardExpiry'

  if ($(CARD_EXPIRATION_SELECT).length > 0 &&
    $(CARD_CODE_SELECT).length > 0 &&
    $(CARD_NUMBER_SELECT).length > 0) {
    $(CARD_NUMBER_SELECT).each(function () {
      var $this = $(this)
      var cardNumberInputId = '#' + $this.attr('id')

      // eslint-disable-next-line no-new
      new Cleave(cardNumberInputId, {
        creditCard: true,
        onCreditCardTypeChanged: function (type) {
          $('.ccType').val(type)
        }
      })
    })

    $(CARD_EXPIRATION_SELECTOR).each(function () {
      var $this = $(this)
      var cardExpiryInputId = '#' + $this.attr('id')

      /* eslint-disable no-new */
      new Cleave(cardExpiryInputId, {
        date: true,
        datePattern: ['m', Spree.translations.card_expire_year_format]
      })
    })

    $(CARD_CODE_SELECTOR).each(function () {
      var $this = $(this)
      var cardCodeInputId = '#' + $this.attr('id')

      /* eslint-disable no-new */
      new Cleave(cardCodeInputId, {
        numericOnly: true,
        blocks: [3]
      })
    })
  }

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
})
