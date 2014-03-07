//= require jquery.payment
$(document).ready(function() {
  if ($("#new_payment").is("*")) {
    $(".cardNumber").payment('formatCardNumber');
    $(".cardExpiry").payment('formatCardExpiry');
    $(".cardCode").payment('formatCardCVC');

    $(".cardNumber").change(function() {
      $(".ccType").val($.payment.cardType(this.value))
    })

    $('.payment_methods_radios').click(
      function() {
        $('.payment-methods').hide();
        if (this.checked) {
          $('#payment_method_' + this.value).show();
        }
      }
    );

    $('.payment_methods_radios').each(
      function() {
        if (this.checked) {
          $('#payment_method_' + this.value).show();
        } else {
          $('#payment_method_' + this.value).hide();
        }
      }
    );

    $('.cvvLink').click(function(event){
      window_name = 'cvv_info';
      window_options = 'left=20,top=20,width=500,height=500,toolbar=0,resizable=0,scrollbars=1';
      window.open($(this).prop('href'), window_name, window_options);
      event.preventDefault();
    });

    $(".card_new").radioControlsVisibilityOfElement('.card_form');

    $('select.jump_menu').change(function(){
      window.location = this.options[this.selectedIndex].value;
    });
  }
});
