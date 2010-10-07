jQuery(document).ready(function(){

  $("#add_product_name").product_autocomplete();

  $("#add_line_item_to_order").live("click", function(){
    if($('#add_variant_id').val() == ''){ return false; }
    update_target = jQuery(this).attr("data-update");
    jQuery.ajax({ dataType: 'script', url: this.href, type: "POST",
        data: {"line_item[variant_id]": $('#add_variant_id').val(),
              "line_item[quantity]": $('#add_quantity').val()},
        success: function(data){
          $("#"+update_target).html(data);
          $('#add_product_name').val('');
          $('#add_variant_id').val('');
          $('#add_quantity').val(1)
        }
    });
    return false; 
  });

});


