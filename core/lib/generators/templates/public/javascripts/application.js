(function($){
  $(document).ready(function(){

    // Remove an item from the cart by setting its quantity to zero and posting the update form 
    $('form#updatecart a.delete').show().click(function(){
      $(this).parents('tr').find('input').val(0);
      $(this).parents('form').submit();
      return false;
    });
    
  });
})(jQuery);
