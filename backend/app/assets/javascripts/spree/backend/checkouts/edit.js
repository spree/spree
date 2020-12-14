//= require_self
/* global customerTemplate, update_state */
// eslint-disable-next-line camelcase
var clear_address_fields = function () {
  var fields = ['firstname', 'lastname', 'company', 'address1', 'address2', 'city', 'zipcode', 'state_id', 'country_id', 'phone']
  $.each(fields, function (i, field) {
    $('#order_bill_address_attributes_' + field).val('')
    $('#order_ship_address_attributes_' + field).val('')
  })
}

$(document).ready(function () {
  if ($('#customer_autocomplete_template').length > 0) {
    window.customerTemplate = Handlebars.compile($('#customer_autocomplete_template').text())
  }

  function formatCustomerResult (customer) {
    if (customer.loading) {
      return customer.text
    }

    return $(customerTemplate({
      customer: customer,
      bill_address: customer.bill_address,
      ship_address: customer.ship_address
    }))
  }

  if ($('#customer_search').length > 0) {
    $('#customer_search').select2({
      placeholder: Spree.translations.choose_a_customer,
      dropdownCssClass: 'customer_search',
      ajax: {
        url: Spree.routes.users_api,
        datatype: 'json',
        cache: true,
        data: function (params) {
          var query = {
            q: {
              'm': 'or',
              'email_start': params.term,
              'ship_address_firstname_start': params.term,
              'ship_address_lastname_start': params.term,
              'bill_address_firstname_start': params.term,
              'bill_address_lastname_start': params.term
            },
            token: Spree.api_key
          }

          return query
        },
        processResults: function (data, page) {
          return { results: data.users }
        }
      },
      templateResult: formatCustomerResult,
      templateSelection: function (customer) {
        $('#order_email').val(customer.email)
        $('#order_user_id').val(customer.id)
        $('#guest_checkout_true').prop('checked', false)
        $('#guest_checkout_false').prop('checked', true)
        $('#guest_checkout_false').prop('disabled', false)

        var billAddress = customer.bill_address
        if (billAddress) {
          $('#order_bill_address_attributes_firstname').val(billAddress.firstname)
          $('#order_bill_address_attributes_lastname').val(billAddress.lastname)
          $('#order_bill_address_attributes_company').val(billAddress.company)
          $('#order_bill_address_attributes_address1').val(billAddress.address1)
          $('#order_bill_address_attributes_address2').val(billAddress.address2)
          $('#order_bill_address_attributes_city').val(billAddress.city)
          $('#order_bill_address_attributes_zipcode').val(billAddress.zipcode)
          $('#order_bill_address_attributes_phone').val(billAddress.phone)

          $('#order_bill_address_attributes_country_id').val(billAddress.country_id).trigger('change').promise().done(function () {
            update_state('b', function () {
              $('#order_bill_address_attributes_state_id').val(billAddress.state_id).trigger('change')
            })
          })
        } else {
          clear_address_fields()
        }
        return customer.email
      }
    })
  }

  var orderUseBillingInput = $('input#order_use_billing')
  var orderUseBilling = function () {
    if (!orderUseBillingInput.is(':checked')) {
      $('#shipping').show()
    } else {
      $('#shipping').hide()
    }
  }

  orderUseBillingInput.click(orderUseBilling)
  orderUseBilling()

  $('#guest_checkout_true').change(function () {
    $('#customer_search').val('')
    $('#order_user_id').val('')
    $('#order_email').val('')
    clear_address_fields()
  })
})
