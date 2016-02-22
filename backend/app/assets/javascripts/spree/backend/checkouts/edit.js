//= require_self
$(document).ready(function() {
  if ($('#customer_autocomplete_template').length > 0) {
    window.customerTemplate = Handlebars.compile($('#customer_autocomplete_template').text());
  }

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
          return {
            q: term,
            token: Spree.api_key
          }
        },
        results: function(data, page) {
          return { results: data.users }
        }
      },
      dropdownCssClass: 'customer_search',
      formatResult: formatCustomerResult,
      formatSelection: function (customer) {
        $('#order_email').val(customer.email);
        $('#user_id').val(customer.id);
        $('#guest_checkout_true').prop("checked", false);
        $('#guest_checkout_false').prop("checked", true);
        $('#guest_checkout_false').prop("disabled", false);

        var billAddress = customer.bill_address;
        if(billAddress) {
          $('#order_bill_address_attributes_firstname').val(billAddress.firstname);
          $('#order_bill_address_attributes_lastname').val(billAddress.lastname);
          $('#order_bill_address_attributes_address1').val(billAddress.address1);
          $('#order_bill_address_attributes_address2').val(billAddress.address2);
          $('#order_bill_address_attributes_city').val(billAddress.city);
          $('#order_bill_address_attributes_zipcode').val(billAddress.zipcode);
          $('#order_bill_address_attributes_phone').val(billAddress.phone);

          $('#order_bill_address_attributes_country_id').select2("val", billAddress.country_id).promise().done(function () {
            update_state('b', function () {
              $('#order_bill_address_attributes_state_id').select2("val", billAddress.state_id);
            });
          });
        }
        return Select2.util.escapeMarkup(customer.email);
      }
    })
  }

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
