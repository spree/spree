// eslint-disable-next-line camelcase, no-unused-vars
function update_state(region, done) {
  'use strict'

  var countryId = $('#' + region + 'country select').val()
  var stateContainer = $('#' + region + 'state').parent()
  var stateSelect = $('#' + region + 'state select')
  var stateInput = $('#' + region + 'state input.state_name')

  $.get(Spree.routes.states_search + '?country_id=' + countryId, function (data) {
    var states = data.states
    var statesRequired = data.states_required
    if (states.length > 0) {
      stateSelect.html('')
      var statesWithBlank = [{
        name: '',
        id: ''
      }].concat(states)
      $.each(statesWithBlank, function (_pos, state) {
        var opt = $(document.createElement('option'))
          .prop('value', state.id)
          .html(state.name)
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
};
