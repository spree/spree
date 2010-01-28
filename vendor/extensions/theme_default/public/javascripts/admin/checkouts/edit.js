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

  $("#customer_search").autocomplete("/admin/users.json", {
    parse: prep_autocomplete_data,
    formatItem: function(item) {
      return format_autocomplete(item);
    }
  }).result(function(event, data, formatted) {
    $('#checkout_email').val(data['email']);

    var addr = data['bill_address'];
    if(addr!=undefined){
      $('#checkout_bill_address_attributes_firstname').val(addr['firstname']);
      $('#checkout_bill_address_attributes_lastname').val(addr['lastname']);
      $('#checkout_bill_address_attributes_address1').val(addr['address1']);
      $('#checkout_bill_address_attributes_address2').val(addr['address2']);
      $('#checkout_bill_address_attributes_city').val(addr['city']);
      $('#checkout_bill_address_attributes_zipcode').val(addr['zipcode']);
      $('#checkout_bill_address_attributes_state_id').val(addr['state_id']);
      $('#checkout_bill_address_attributes_country_id').val(addr['country_id']);
      $('#checkout_bill_address_attributes_phone').val(addr['phone']);
    }

    var addr = data['ship_address'];
    if(addr!=undefined){
      $('#checkout_ship_address_attributes_firstname').val(addr['firstname']);
      $('#checkout_ship_address_attributes_lastname').val(addr['lastname']);
      $('#checkout_ship_address_attributes_address1').val(addr['address1']);
      $('#checkout_ship_address_attributes_address2').val(addr['address2']);
      $('#checkout_ship_address_attributes_city').val(addr['city']);
      $('#checkout_ship_address_attributes_zipcode').val(addr['zipcode']);
      $('#checkout_ship_address_attributes_state_id').val(addr['state_id']);
      $('#checkout_ship_address_attributes_country_id').val(addr['country_id']);
      $('#checkout_ship_address_attributes_phone').val(addr['phone']);
    }
  });

});

