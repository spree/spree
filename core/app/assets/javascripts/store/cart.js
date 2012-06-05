(function($){
  $(document).ready(function(){
    if($('form#update-cart').is('*')){
      $('form#update-cart a.delete').show().on('click', function(e){
        $(this).parents('.line-item').first().find('input.line_item_quantity').val(0);
        $(this).parents('form').first().submit();
        e.preventDefault();
      });
    }
  });
})(jQuery);
