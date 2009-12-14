jQuery(document).ready(function(){
  $.each($('td.qty input'), function(i, inpt){
    $(inpt).delayedObserver(0.5, function(object, value) {

      var id = object.attr('id').replace("order_line_items_attributes_", "").replace("_quantity", "");
      id = "#order_line_items_attributes_" + id + "_id";

      jQuery.ajax({
        type: "POST",
        url: "/admin/orders/" + $('input#order_number').val() + "/line_items/" + $(id).val(),
        data: ({_method: "put", "line_item[quantity]": value}),
        success: function(html){ $('#order-form-wrapper').html(html)}
      });

    });
  });
});