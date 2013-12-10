//= require_self
//= require jquery.payment
$(document).ready(function() {
  if ($('#customer_autocomplete_template').length > 0) {
    window.customerTemplate = Handlebars.compile($('#customer_autocomplete_template').text());
  }

  if ($("#card_number").is("*")) {
    $("#card_number").payment('formatCardNumber')
      $("#card_expiry").payment('formatCardExpiry')
      $("#card_code").payment('formatCardCVC')

      $("#card_number").change(function() {
        $("#cc_type").val($.payment.cardType(this.value))
      })
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
          return { q: term }
        },
        results: function(data, page) {
          return { results: data }
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

        return customer.email;
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
