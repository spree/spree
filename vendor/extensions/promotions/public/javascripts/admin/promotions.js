var initProductRuleSourceField = function(){
  
  $products_source_field = jQuery('.products_rule_products_source_field input');
  $products_source_field.click(function() {
    $rule_container = jQuery(this).parents('.promotion-rule');
    if(this.checked){
      if(this.value == 'manual'){
        $rule_container.find('.products_rule_products').show();
        $rule_container.find('.products_rule_product_group').hide();
      } else {
        $rule_container.find('.products_rule_products').hide();
        $rule_container.find('.products_rule_product_group').show();
      }
    }
  });
  $products_source_field.each(function() { 
    $(this).triggerHandler('click');
  });

};


jQuery(document).ready(function() {
  initProductRuleSourceField();
});

