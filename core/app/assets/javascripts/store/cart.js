(function($){
  $(document).ready(function(){
    if($('form#update-cart').is('*')){
      $('form#update-cart a.delete').show().live('click', function(e){
        $(this).parents('tr').find('input.line_item_quantity').val(0);
        $(this).parents('form').submit();
        e.preventDefault();
      });
    }
  });
})(jQuery);
