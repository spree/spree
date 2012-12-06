$(document).ready(function() {
  window.customerTemplate = Handlebars.compile($('#customer_autocomplete_template').text());

  formatCustomerResult = function(customer) {
    return customerTemplate({
      customer: customer,
      bill_address: customer.bill_address,
      ship_address: customer.ship_address
    })
  }

  if ($("#customer_search").length > 0) {
    $("#customer_search").select2({
      placeholder: Spree.translations.choose_a_customer,
      ajax: {
        url: Spree.routes.user_search,
        datatype: 'json',
        data: function(term, page) {
          return { q: term }
        },
        results: function(data, page) {
          return { results: data }
        }
      },
      formatResult: formatCustomerResult,
      formatSelection: function (customer) {
        _.each(['bill_address', 'ship_address'], function(address) {
          var data = customer[address];
          if(data != undefined) {
            $('#order_' + address + '_attributes_firstname').val(data['firstname']);
            $('#order_' + address + '_attributes_lastname').val(data['lastname']);
            $('#order_' + address + '_attributes_company').val(data['company']);
            $('#order_' + address + '_attributes_address1').val(data['address1']);
            $('#order_' + address + '_attributes_address2').val(data['address2']);
            $('#order_' + address + '_attributes_city').val(data['city']);
            $('#order_' + address + '_attributes_zipcode').val(data['zipcode']);
            $('#order_' + address + '_attributes_state_id').select2("val", data['state_id']);
            $('#order_' + address + '_attributes_country_id').select2("val", data['country_id']);
            $('#order_' + address + '_attributes_phone').val(data['phone']);
          }
        });

        $('#order_email').val(customer.email);
        $('#user_id').val(customer.id);
        $('#guest_checkout_true').prop("checked", false);
        $('#guest_checkout_false').prop("checked", true);
        $('#guest_checkout_false').prop("disabled", false);

        return customer.email;
      }
    })
  }


  $('input#order_use_billing').click(function() {
    if(!$(this).is(':checked')) {
      $('#shipping').show();
      $('#shipping input').prop("disabled", false);
      $('#shipping select').prop("disabled", false);
    } else {
      $('#shipping').hide();
      $('#shipping input').prop("disabled", true);
      $('#shipping select').prop("disabled", true);
    }
  });

  $('#guest_checkout_true').change(function() {
    $('#customer_search').val("");
    $('#user_id').val("");
    $('#checkout_email').val("");

    var fields = ["firstname", "lastname", "company", "address1", "address2",
              "city", "zipcode", "state_id", "country_id", "phone"]
    $.each(fields, function(i, field) {
      $('#order_bill_address_attributes' + field).val("");
      $('#order_ship_address_attributes' + field).val("");
    })
  });
});


