//= require_self
$(document).ready(function() {
  function performCustomerSearch(){
    var query = $('.js-change-customer-search input').val();
    $('.js-change-customer-index').html("Loading..");

    $.ajax({
      type: 'GET',
      url: '/admin/users',
      data: {
        q: {
          email_cont: query
        }
      }
    }).done(function (data) {
      $('.js-change-customer-index').html(data);
    }).error(function (msg) {
      console.log(msg);
    });
  }

  $(".js-change-customer-search-form").submit(function(){
    performCustomerSearch();
    return false;
  });

  $('.js-change-customer-search .btn').click(function(){
    performCustomerSearch();
  });

  $(document).on("click", ".js-change-customer-index a", function(e) {
    e.preventDefault();
    var customer_id = $(this).data("id");
    var customer_email = $(this).text();

    $("#order_user_id").val(customer_id);
    $('#changeCustomer').modal('hide');
    if($("#order_email").val().length == 0){
      $("#order_email").val(customer_email);
    }
    if($("#order_bill_address_attributes_firstname").val().length > 0){
      // if not this order is created manually
      // we need to fill in the billing address before we save
      $("form.edit_order").submit();
    }
  });

  var order_use_billing_input = $('input#order_use_billing');

  var order_use_billing = function () {
    if (!order_use_billing_input.is(':checked')) {
      $('#shipping').show();
    } else {
      $('#shipping').hide();
    }
  };

  order_use_billing_input.click(function() {
    order_use_billing();
  });

  order_use_billing();

  $('#guest_checkout_true').change(function() {
    $('#checkout_email').val("");

    var fields = ["firstname", "lastname", "company", "address1", "address2",
              "city", "zipcode", "state_id", "country_id", "phone"]
    $.each(fields, function(i, field) {
      $('#order_bill_address_attributes' + field).val("");
      $('#order_ship_address_attributes' + field).val("");
    })
  });
});
