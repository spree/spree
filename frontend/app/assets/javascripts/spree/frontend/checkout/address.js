Spree.ready(function ($) {
  Spree.onAddress = function () {
    if ($('#checkout_form_address').length) {
      Spree.updateState = function (region) {
        var countryId = getCountryId(region)
        if (countryId != null) {
          if (Spree.Checkout[countryId] == null) {
            $.ajax({
              async: false, method: 'GET', url: Spree.pathFor('/api/v2/storefront/countries/' + countryId + '?include=states'), dataType: 'json'
            }).done(function (data) {
              var json = data.included; var xStates = []
              for (var i = 0; i < json.length; i++) {
                var obj = json[i]; xStates.push({ 'id': obj.id, 'name': obj.attributes.name })
              }
              Spree.Checkout[countryId] = {
                states: xStates,
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
        var requiredIndicator = $('span#required_marker').first().text()
        var zipcodeRequired = data.zipcode_required
        var zipcodePara = $('#' + region + 'zipcode')
        var zipcodeInput = zipcodePara.find('input')
        var zipcodeLabel = zipcodePara.find('label')
        var zipcodeLabelText = zipcodeInput.attr('aria-label')

        if (zipcodeRequired) {
          var zipText = zipcodeLabelText + ' ' + requiredIndicator
          zipcodeInput.prop('required', true).attr('placeholder', zipText)
          zipcodeLabel.text('')
          zipcodeLabel.text(zipText)
          zipcodeInput.addClass('required')
        } else {
          zipcodeInput.prop('required', false).attr('placeholder', zipcodeLabelText)
          zipcodeLabel.text('')
          zipcodeLabel.text(zipcodeLabelText)
          zipcodeInput.removeClass('required')
        }
      }

      Spree.fillStates = function (data, region) {
        var selected
        var statesRequired = data.states_required
        var states = data.states
        var statePara = $('#' + region + 'state')
        var stateSelect = statePara.find('select')
        var stateInput = statePara.find('input')
        var stateLabel = statePara.find('label')
        var stateSelectImg = statePara.find('img')
        var stateSpanRequired = statePara.find('abbr')

        if (states.length > 0) {
          selected = parseInt(stateSelect.val())
          stateSelect.html('')
          $.each(states, function (idx, state) {
            var opt = $(document.createElement('option')).attr('value', state.id).html(state.name)
            if (selected.toString(10) === state.id.toString(10)) {
              opt.prop('selected', true)
            }
            stateSelect.append(opt)
          })
          stateSelect.prop('required', false)
          stateSelect.prop('disabled', false).show()
          stateLabel.addClass('state-select-label')
          stateInput.hide().prop('disabled', true)
          statePara.show()
          stateSpanRequired.hide()
          stateSelect.removeClass('required')

          if (statesRequired) {
            stateSelect.addClass('required')
            stateSelectImg.show()
            stateSpanRequired.show()
            stateSelect.prop('required', true)
          }
          stateSelect.removeClass('hidden')
          stateInput.removeClass('required')
        } else {
          stateSelect.hide().prop('disabled', true)
          stateLabel.removeClass('state-select-label')
          stateSelectImg.hide()
          stateInput.show()
          if (statesRequired) {
            stateSpanRequired.show()
            stateLabel.removeClass('state-select-label')
            stateInput.addClass('required form-control')
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
