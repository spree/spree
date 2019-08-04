Spree.ready(function ($) {
  Spree.onAddress = function () {
    if ($('#checkout_form_address').length) {
      Spree.updateState = function (region) {
          var countryId = getCountryId(region)
          if (countryId != null) {
            if (Spree.Checkout[countryId] == null) {
              $.ajax({
                async: false,
                method: 'GET',
                url: "/api/v2/storefront/countries/" + countryId + "?include=states",
                dataType: 'json'
                }).done(function (data) {
                var json = data.included
                var x_states = []
                for(var i = 0; i < json.length; i++) {
                    var obj = json[i];
                    x_states.push(obj.attributes)
                }
                Spree.Checkout[countryId] = {
                  states: x_states,
                  states_required: data.data.attributes.states_required,
                  zipcode_required: data.data.attributes.zipcode_required
                }
                Spree.fillStates(Spree.Checkout[countryId], region)
                Spree.toggleZipcode(Spree.Checkout[countryId], region)
              })
            } else {
              Spree.fillStates(Spree.Checkout[countryId], region)
              Spree.toggleZipcode(Spree.Checkout[countryId], region)
            }
        }
      }

        Spree.toggleZipcode = function (data, region) {
          var zipcodeRequired = data.zipcode_required
          var zipcodePara = $('#' + region + 'zipcode')
          var zipcodeInput = zipcodePara.find('input')
          var zipcodeSpanRequired = zipcodePara.find('[id$="zipcode-required"]')

          if (zipcodeRequired) {
            zipcodeInput.removeClass('hidden')
            zipcodeInput.addClass('required')
            zipcodeInput.prop('required',true)
            zipcodeInput.prop('disabled', false).show()
            zipcodePara.show()

          } else {
            zipcodeInput.val('')
            zipcodeSpanRequired.hide()
            zipcodeInput.removeClass('required')
            zipcodeInput.prop('required',false).hide()
            zipcodePara.hide()
          }
        }

        Spree.fillStates = function (data, region) {
          var selected, statesWithBlank
          var statesRequired = data.states_required
          var states = data.states
          var statePara = $('#' + region + 'state')
          var stateSelect = statePara.find('select')
          var stateInput = statePara.find('input')
          var stateSpanRequired = statePara.find('[id$="state-required"]')

          if (states.length > 0) {
            selected = parseInt(stateSelect.val())
            stateSelect.html('')
            statesWithBlank = [
              {
                name: '',
                id: ''
              }
            ].concat(states)
            $.each(statesWithBlank, function (idx, state) {
              var opt = $(document.createElement('option')).attr('value', state.id).html(state.name)
              if (selected === state.id) {
                opt.prop('selected', true)
              }
              stateSelect.append(opt)
            })
            stateSelect.prop('disabled', false).show()
            stateInput.hide().prop('disabled', true)
            statePara.show()
            stateSpanRequired.show()
            if (statesRequired) {
              stateSelect.addClass('required')

            }
            stateSelect.removeClass('hidden')
            stateInput.removeClass('required')
            stateSelect.prop('required',true)
          } else {
            stateSelect.hide().prop('disabled', true)
            stateInput.show()
            if (statesRequired) {
              stateSpanRequired.show()
              stateInput.addClass('required')
            } else {
              stateInput.val('')
              stateSpanRequired.hide()
              stateInput.removeClass('required')
            }
            statePara.toggle(!!statesRequired)
            stateInput.prop('disabled', !statesRequired)
            stateInput.removeClass('hidden')
            stateSelect.removeClass('required')
          }
        }
        $('#bcountry select').change(function () {
          Spree.updateState('b')
        })
        $('#scountry select').change(function () {
          Spree.updateState('s')
        })
        Spree.updateState('b')

        var orderUseBilling = $('input#order_use_billing')
        orderUseBilling.change(function () {
          updateShippingFormState(orderUseBilling)
        })
        updateShippingFormState(orderUseBilling)
        }
        function updateShippingFormState (orderUseBilling) {
          if (orderUseBilling.is(':checked')) {
            $('#shipping .inner').hide()
            $('#shipping .inner input, #shipping .inner select').prop('disabled', true)
          } else {
            $('#shipping .inner').show()
            $('#shipping .inner input, #shipping .inner select').prop('disabled', false)
            Spree.updateState('s')
          }
        }

        function getCountryId (region) {
          return $('#' + region + 'country select').val()
        }

  }
Spree.onAddress()
})
