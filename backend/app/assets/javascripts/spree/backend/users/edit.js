$( document ).ready(function() {
  var use_billing = $('#user_use_billing');

  if(use_billing.is(':checked')) {
    $('#shipping').hide();
  }

  use_billing.change(function() {
    if(this.checked){
       $('#shipping').hide();
       return $('#shipping input, #shipping select').prop('disabled', true);
     }
     else {
       $('#shipping').show();
       $('#shipping input, #shipping select').prop('disabled', false);
     }
  });
});
