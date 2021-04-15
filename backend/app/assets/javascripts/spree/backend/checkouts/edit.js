function clearAddressFields(addressKinds) {
  if (addressKinds === undefined) {
    addressKinds = ['ship', 'bill']
  }
  addressKinds.forEach(function(addressKind) {
    ADDRESS_FIELDS.forEach(function(field) {
      $('#order_' + addressKind + '_address_attributes_' + field).val('')
    })
  })
}

function formatCustomerResult(customer) {
  var escapedResult = window.customerTemplate({
    customer: customer,
    bill_address: customer.bill_address,
    ship_address: customer.ship_address
  })
  return $(escapedResult)
}

function formatCustomerAddress(address, kind) {
  $('#order_' + kind + '_address_attributes_firstname').val(address.firstname)
  $('#order_' + kind + '_address_attributes_lastname').val(address.lastname)
  $('#order_' + kind + '_address_attributes_address1').val(address.address1)
  $('#order_' + kind + '_address_attributes_company').val(address.company)
  $('#order_' + kind + '_address_attributes_address2').val(address.address2)
  $('#order_' + kind + '_address_attributes_city').val(address.city)
  $('#order_' + kind + '_address_attributes_zipcode').val(address.zipcode)
  $('#order_' + kind + '_address_attributes_phone').val(address.phone)
  $('#order_' + kind + '_address_attributes_phone').val(address.phone)
  $('#order_' + kind + '_address_attributes_country_id').val(address.country.id)
  $('#order_' + kind + '_address_attributes_country_id').trigger('change')

  var stateSelect = $('#order_' + kind + '_address_attributes_state_id')

  updateAddressState(kind.charAt(0), function() {
    if (address.state) {
      stateSelect.val(address.state.id).trigger('change')
    }
  })
}

function formatCustomerSelection(customer) {
  $('#order_email').val(customer.email)
  $('#order_user_id').val(customer.id)
  $('#guest_checkout_true').prop('checked', false)
  $('#guest_checkout_false').prop('checked', true)
  $('#guest_checkout_false').prop('disabled', false)

  var billAddress = customer.bill_address
  var shipAddress = customer.ship_address

  if (billAddress) {
    formatCustomerAddress(billAddress, 'bill')
  } else {
    clearAddressFields(['bill'])
  }

  if (shipAddress) {
    formatCustomerAddress(shipAddress, 'ship')
  } else {
    clearAddressFields(['ship'])
  }

  return customer.email
}

$.fn.customerAutocomplete = function() {
  var jsonApiUsers = {}

  this.select2({
    minimumInputLength: 3,
    placeholder: Spree.translations.choose_a_customer,
    ajax: {
      url: Spree.routes.users_api_v2,
      datatype: 'json',
      headers: Spree.apiV2Authentication(),
      data: function (params) {
        return {
          filter: {
            'm': 'or',
            email_i_cont: params.term,
            addresses_firstname_start: params.term,
            addresses_lastname_start: params.term
          },
          include: 'ship_address.country,ship_address.state,bill_address.country,bill_address.state'
        }
      },
      success: function(data) {
        var JSONAPIDeserializer = require('jsonapi-serializer').Deserializer
        new JSONAPIDeserializer({ keyForAttribute: 'snake_case' }).deserialize(data, function (_err, users) {
          jsonApiUsers = users
        })
      },
      processResults: function (_data) {
        return { results: jsonApiUsers } // we need to return deserialized json api data
      }
    },
    templateResult: formatCustomerResult
  }).on('select2:select', function (e) {
    var data = e.params.data;
    formatCustomerSelection(data)
  })
}

document.addEventListener('DOMContentLoaded', function() {
  $('#customer_search').customerAutocomplete()

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
    clearAddressFields()
  })
})
