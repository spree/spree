$(document).ready(function(){

  $("#add_line_item_to_order").on("click", function(){
    if($('#add_variant_id').val() == ''){ return false; }
    update_target = $(this).attr("data-update");
    $.ajax({ dataType: 'script', url: this.href, type: "POST",
        data: {"line_item[variant_id]": $('#add_variant_id').val(),
              "line_item[quantity]": $('#add_quantity').val()}
    });
    return false;
  });

  $(".variant_autocomplete").variantAutocomplete();

});
