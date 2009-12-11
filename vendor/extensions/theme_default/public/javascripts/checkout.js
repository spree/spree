jQuery(document).ready(function($){
  
  $('input#checkout_use_billing').click(function() {
    if(this.checked) {
      $('#shipping .inner').hide();
      $('#shipping .inner input').attr('disabled', 'disabled');
    } else {
      $('#shipping .inner').show();
      $('#shipping .inner input').removeAttr('disabled', 'disabled');
    }
  });
  
});