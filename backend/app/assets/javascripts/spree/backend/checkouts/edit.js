//= require_self
/* global customerTemplate, update_state */
// eslint-disable-next-line camelcase

function clear_billing_address_fields () {
  var fields = ['firstname', 'lastname', 'company', 'address1', 'address2',
    'city', 'zipcode', 'state_id', 'country_id', 'phone']
  $.each(fields, function (i, field) {
    $('#order_bill_address_attributes_' + field).val('')
  })
}

function clear_shipping_address_fields () {
  var fields = ['firstname', 'lastname', 'company', 'address1', 'address2',
    'city', 'zipcode', 'state_id', 'country_id', 'phone']
  $.each(fields, function (i, field) {
    $('#order_ship_address_attributes_' + field).val('')
  })
}

function clear_address_fields () {
  clear_billing_address_fields ()
  clear_shipping_address_fields ()
}

function formatCustomerResult (customer) {
  var escapedResult =  customerTemplate({
    customer: customer,
    bill_address: customer.bill_address,
    ship_address: customer.ship_address
  })
  return $(escapedResult)
}

function formatCustomerSelection (customer) {
  $('#order_email').val(customer.email)
  $('#order_user_id').val(customer.id)
  $('#guest_checkout_true').prop('checked', false)
  $('#guest_checkout_false').prop('checked', true)
  $('#guest_checkout_false').prop('disabled', false)

  var billAddress = customer.bill_address
  var shipAddress = customer.ship_address

  if (billAddress) {
    $('#order_bill_address_attributes_firstname').val(billAddress.firstname)
    $('#order_bill_address_attributes_lastname').val(billAddress.lastname)
    $('#order_bill_address_attributes_address1').val(billAddress.address1)
    $('#order_bill_address_attributes_company').val(billAddress.company)
    $('#order_bill_address_attributes_address2').val(billAddress.address2)
    $('#order_bill_address_attributes_city').val(billAddress.city)
    $('#order_bill_address_attributes_zipcode').val(billAddress.zipcode)
    $('#order_bill_address_attributes_phone').val(billAddress.phone)
    $('#order_bill_address_attributes_phone').val(billAddress.phone)
    $('#order_bill_address_attributes_country_id').select2().val(billAddress.country_id)
    $('#order_bill_address_attributes_country_id').select2().trigger('change.select2').promise().done(function () {
      update_state('b', function () {
        if ($('span#bstate select.select2').find("option[value='" + billAddress.state_id + "']").length) {
          $('span#bstate select.select2').val(billAddress.state_id).trigger('change.select2')
        }
      })
    })
  } else {
    clear_billing_address_fields ()
  }

  if (shipAddress) {
    $('#order_ship_address_attributes_firstname').val(shipAddress.firstname)
    $('#order_ship_address_attributes_lastname').val(shipAddress.lastname)
    $('#order_ship_address_attributes_address1').val(shipAddress.address1)
    $('#order_ship_address_attributes_company').val(shipAddress.company)
    $('#order_ship_address_attributes_address2').val(shipAddress.address2)
    $('#order_ship_address_attributes_city').val(shipAddress.city)
    $('#order_ship_address_attributes_zipcode').val(shipAddress.zipcode)
    $('#order_ship_address_attributes_phone').val(shipAddress.phone)
    $('#order_ship_address_attributes_phone').val(shipAddress.phone)
    $('#order_ship_address_attributes_country_id').select2().val(shipAddress.country_id)
    $('#order_ship_address_attributes_country_id').select2().trigger('change.select2').promise().done(function () {
      update_state('s', function () {
        if ($('span#sstate select.select2').find("option[value='" + shipAddress.state_id + "']").length) {
          $('span#sstate select.select2').val(shipAddress.state_id).trigger('change.select2')
        }
      })
    })
  } else {
    clear_shipping_address_fields ()
  }

  return customer.email
}

// Select2-AJAX
// Searches for Users
// Used in Order -> Customer
function set_customer_search_select (selector) {
  $(selector).select2({
    minimumInputLength: 3,
    placeholder: Spree.translations.choose_a_customer,
    ajax: {
      url: Spree.routes.users_api,
      datatype: 'json',
      data: function (params, page) {
        return {
          q: {
            'm': 'or',
            email_start: params.term,
            ship_address_firstname_start: params.term,
            ship_address_lastname_start: params.term,
            bill_address_firstname_start: params.term,
            bill_address_lastname_start: params.term
          },
          token: Spree.api_key
        }
      },
      processResults: function (data, page) {
        return { results: data['users'] }
      }
    },
    templateResult: formatCustomerResult
  }).on('select2:select', function (e) {
    var data = e.params.data;
    formatCustomerSelection(data)
  });
}

document.addEventListener('DOMContentLoaded', function() {
  // Set up Select 2 on page ready
  if ($('#customer_search').length > 0) {
    set_customer_search_select('#customer_search')
  }

  if ($('#customer_autocomplete_template').length > 0) {
    window.customerTemplate = Handlebars.compile($('#customer_autocomplete_template').text())
  }

  // Handle Billing Shipping Address
  var orderUseBillingInput = $('input#order_use_billing')

  var orderUseBilling = function () {
    if (!orderUseBillingInput.is(':checked')) {
      $('#shipping').show()
    } else {
      $('#shipping').hide()
    }
  }

  // On page load hide shipping address from
  orderUseBilling()

  // On click togggle shipping address from
  orderUseBillingInput.click(orderUseBilling)

  // If guest checkout clear fields
  $('#guest_checkout_true').change(function () {
    $('#customer_search').val('')
    $('#order_user_id').val('')
    $('#order_email').val('')
    clear_address_fields()
  })
})
