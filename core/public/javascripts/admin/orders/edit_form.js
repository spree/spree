  $.each($('td.qty input'), function(i, inpt){

    $(inpt).delayedObserver(function() {

      var id = $(this).attr('id').replace("order_line_items_attributes_", "").replace("_quantity", "");
      id = "#order_line_items_attributes_" + id + "_id";

      jQuery.ajax({
        type: "POST",
        url: "/admin/orders/" + $('input#order_number').val() + "/line_items/" + $(id).val(),
        data: ({_method: "put", "line_item[quantity]": $(this).val()}),
        success: function(html){ $('#order-form-wrapper').html(html)}
      });

    }, 0,5);
  });
