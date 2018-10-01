// eslint-disable-next-line camelcase, no-unused-vars
function update_state (region, done) {
  'use strict'

  var country = $('span#' + region + 'country .select2').select2('val')
  var stateSelect = $('span#' + region + 'state select.select2')
  var stateInput = $('span#' + region + 'state input.state_name')

  $.get(Spree.routes.states_search + '?country_id=' + country, function (data) {
    var states = data.states
    if (states.length > 0) {
      stateSelect.html('')
      var statesWithBlank = [{
        name: '',
        id: ''
      }].concat(states)
      $.each(statesWithBlank, function (pos, state) {
        var opt = $(document.createElement('option'))
          .prop('value', state.id)
          .html(state.name)
        stateSelect.append(opt)
      })
      stateSelect.prop('disabled', false).show()
      stateSelect.select2()
      stateInput.hide().prop('disabled', true)
    } else {
      stateInput.prop('disabled', false).show()
      stateSelect.select2('destroy').hide()
    }

    if (done) done()
  })
};
