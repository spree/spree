$(document).ready(function(){
  $('input#order_use_billing').click(function() {
    show_billing(!$(this).is(':checked'));
  });

  $('#guest_checkout_true').change(function() {
    $('#customer_search').val("");
    $('#user_id').val("");
    $('#checkout_email').val("");
    $('#guest_checkout_false').prop("disabled", true);

    $('#order_bill_address_attributes_firstname').val("");
    $('#order_bill_address_attributes_lastname').val("");
    $('#order_bill_address_attributes_company').val("");
    $('#order_bill_address_attributes_address1').val("");
    $('#order_bill_address_attributes_address2').val("");
    $('#order_bill_address_attributes_city').val("");
    $('#order_bill_address_attributes_zipcode').val("");
    $('#order_bill_address_attributes_state_id').val("");
    $('#order_bill_address_attributes_country_id').val("");
    $('#order_bill_address_attributes_phone').val("");

    $('#order_ship_address_attributes_firstname').val("");
    $('#order_ship_address_attributes_lastname').val("");
    $('#order_bill_address_attributes_company').val("");
    $('#order_ship_address_attributes_address1').val("");
    $('#order_ship_address_attributes_address2').val("");
    $('#order_ship_address_attributes_city').val("");
    $('#order_ship_address_attributes_zipcode').val("");
    $('#order_ship_address_attributes_state_id').val("");
    $('#order_ship_address_attributes_country_id').val("");
    $('#order_ship_address_attributes_phone').val("");
  });

  var show_billing = function(show) {
    if(show) {
      $('#shipping').show();
      $('#shipping input').prop("disabled", false);
      $('#shipping select').prop("disabled", false);
    } else {
      $('#shipping').hide();
      $('#shipping input').prop("disabled", true);
      $('#shipping select').prop("disabled", true);
    }
  }

});


