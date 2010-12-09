jQuery(document).ready(function(){
  add_address = function(addr){
    var html = "";
    if(addr!=undefined){
      html += addr['firstname'] + " " + addr['lastname'] + ", ";
      html += addr['address1'] + ", " + addr['address2'] + ", ";
      html += addr['city'] + ", ";

      if(addr['state_id']!=null){
        html += addr['state']['name'] + ", ";
      }else{
        html += addr['state_name'] + ", ";
      }

      html += addr['country']['name'];
    }
    return html;
  }

  format_autocomplete = function(data){
    var html = "<h4>" + data['email'] +"</h4>";
    html += "<span><strong>Billing:</strong> ";
    html += add_address(data['bill_address']);
    html += "</span>";

    html += "<span><strong>Shipping:</strong> ";
    html += add_address(data['ship_address']);
    html += "</span>";

    return html
  }

  prep_autocomplete_data = function(data){
    return $.map(eval(data), function(row) {
      return {
          data: row['user'],
          value: row['user']['email'],
          result: row['user']['email']
      }
    });
  }

  $("#customer_search").autocomplete("/admin/users.json?authenticity_token=" + $('meta[name=csrf-token]').attr("content"), {
    minChars: 5,
    delay: 1500,
    parse: prep_autocomplete_data,
    formatItem: function(item) {
      return format_autocomplete(item);
    }
  }).result(function(event, data, formatted) {
    $('#user_id').val(data['id']);
    $('#guest_checkout_true').removeAttr("checked");
    $('#guest_checkout_false').attr("checked", "checked");
    $('#guest_checkout_false').removeAttr("disabled");
    $('#order_email').val(data['email']);

    var addr = data['bill_address'];
    if(addr!=undefined){
      $('#order_bill_address_attributes_firstname').val(addr['firstname']);
      $('#order_bill_address_attributes_lastname').val(addr['lastname']);
      $('#order_bill_address_attributes_address1').val(addr['address1']);
      $('#order_bill_address_attributes_address2').val(addr['address2']);
      $('#order_bill_address_attributes_city').val(addr['city']);
      $('#order_bill_address_attributes_zipcode').val(addr['zipcode']);
      $('#order_bill_address_attributes_state_id').val(addr['state_id']);
      $('#order_bill_address_attributes_country_id').val(addr['country_id']);
      $('#order_bill_address_attributes_phone').val(addr['phone']);
    }

    var addr = data['ship_address'];
    if(addr!=undefined){
      $('#order_ship_address_attributes_firstname').val(addr['firstname']);
      $('#order_ship_address_attributes_lastname').val(addr['lastname']);
      $('#order_ship_address_attributes_address1').val(addr['address1']);
      $('#order_ship_address_attributes_address2').val(addr['address2']);
      $('#order_ship_address_attributes_city').val(addr['city']);
      $('#order_ship_address_attributes_zipcode').val(addr['zipcode']);
      $('#order_ship_address_attributes_state_id').val(addr['state_id']);
      $('#order_ship_address_attributes_country_id').val(addr['country_id']);
      $('#order_ship_address_attributes_phone').val(addr['phone']);
    }
  });


  $('input#order_use_billing').click(function() {
    show_billing(!$(this).is(':checked'));
  });

  $('#guest_checkout_true').change(function() {
    $('#customer_search').val("");
    $('#user_id').val("");
    $('#checkout_email').val("");
    $('#guest_checkout_false').attr("disabled", "true");

    $('#order_bill_address_attributes_firstname').val("");
    $('#order_bill_address_attributes_lastname').val("");
    $('#order_bill_address_attributes_address1').val("");
    $('#order_bill_address_attributes_address2').val("");
    $('#order_bill_address_attributes_city').val("");
    $('#order_bill_address_attributes_zipcode').val("");
    $('#order_bill_address_attributes_state_id').val("");
    $('#order_bill_address_attributes_country_id').val("");
    $('#order_bill_address_attributes_phone').val("");

    $('#order_ship_address_attributes_firstname').val("");
    $('#order_ship_address_attributes_lastname').val("");
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
      $('#shipping input').removeAttr('disabled', 'disabled');
      $('#shipping select').removeAttr('disabled', 'disabled');
    } else {
      $('#shipping').hide();
      $('#shipping input').attr('disabled', 'disabled');
      $('#shipping select').attr('disabled', 'disabled');
    }
  }

});


