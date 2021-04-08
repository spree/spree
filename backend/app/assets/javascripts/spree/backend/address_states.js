// eslint-disable-next-line camelcase, no-unused-vars
function update_state(region, done) {
  'use strict'

  var countryId = $('#' + region + 'country select').val()
  var stateContainer = $('#' + region + 'state').parent()
  var stateSelect = $('#' + region + 'state select')
  var stateInput = $('#' + region + 'state input.state_name')

  fetch(Spree.routes.countries_api_v2 + '/' + countryId + '?include=states', {
    headers: Spree.apiV2Authentication()
  }).then(function (response) {
    switch (response.status) {
      case 200:
        response.json().then(function (json) {
          var states = json.included
          var statesRequired = json.data.attributes.states_required
          if (states.length > 0) {
            stateSelect.html('')
            $.each(states, function (_pos, state) {
              var opt = $(document.createElement('option'))
                .prop('value', state.id)
                .html(state.attributes.name)
              stateSelect.append(opt).trigger('change')
            })
            stateSelect.prop('disabled', false).show()
            stateSelect.select2()
            stateInput.hide().prop('disabled', true)
            stateContainer.show()
          } else {
            stateSelect.val(null).trigger('change')
            if (stateSelect.data('select2')) {
              stateSelect.select2('destroy')
            }
            stateSelect.hide()
            if (statesRequired) {
              stateInput.prop('disabled', false).show()
            } else {
              stateContainer.hide()
            }
          }
          if (done) done()
        })
        break
    }
  })
}
