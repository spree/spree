//= require jquery.payment
$(document).ready(function () {
  if ($('#new_payment').length) {

    var cleave = new Cleave('.cardNumber', {
      creditCard: true,
      onCreditCardTypeChanged: function (type) {
          $('.ccType').val(type)
      }
    })

    var cleaveDate = new Cleave('.cardExpiry', {
      date: true,
      datePattern: ['m', 'Y']
    })

    var cleaveCCV = new Cleave('.cardCode', {
      blocks: [3]
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

    $('select.jump_menu').change(function () {
      window.location = this.options[this.selectedIndex].value
      console.log(this.options[this.selectedIndex].value);
    })

  }
})
