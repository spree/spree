function updateAddressState(region, successCallback) {
  const countryId = $('#' + region + 'country select').val()
  const stateContainer = $('#' + region + 'state').parent()
  const stateSelect = $('#' + region + 'state select')
  const stateInput = $('#' + region + 'state input.state_name')

  fetch(Spree.routes.countries_api_v2 + '/' + countryId + '?include=states', {
    headers: Spree.apiV2Authentication()
  }).then((response) => {
    switch (response.status) {
      case 200:
        response.json().then((json) => {
          const states = json.included
          const statesRequired = json.data.attributes.states_required
          if (states.length > 0) {
            stateSelect.html('')
            $.each(states, function (_pos, state) {
              const opt = $(document.createElement('option'))
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
          if (successCallback) successCallback()
        })
        break
    }
  })
}
