// Attach a 'js-country-states' class to a wrapper around both fields
// Attach a 'js-country' class to country select wrapper
// Attach a 'js-state' class to the state select wrapper
// Now the states will be refreshed as the country changes.

$(document).ready(function () {
  $('.js-country select').on('change', function () {
    var $parent = $(this).parents('.js-country-states');
    countryStates.requestStates($parent);
  });
});

var countryStates = {
  requestStates: function($parent){
    var countryId = countryStates.getCountryId($parent);

    $.ajax({
      type: 'GET',
      url: Spree.routes.states_search,
      data: {
        country_id: countryId
      }
    }).done(function (data) {
      countryStates.buildStatesSelect(data, $parent);
    }).error(function (msg) {
      console.log(msg);
    });
  },

  getCountryId: function($parent){
    return $('.js-country select.select2', $parent).val();
  },

  buildStatesSelect: function(data, $parent){
    var states = data.states;
    var statesRequired = data.states_required;

    var statePara = $('.js-state', $parent);
    var stateSelect = statePara.find('select');
    var stateSelect2 = statePara.find('.select2');
    var stateInput = statePara.find('input');

    if(states.length > 0){
      var selected = parseInt(stateSelect.val(), 10);
      stateSelect.html('');
      var statesWithBlank = [{ name: '', id: ''}].concat(states);
      $.each(statesWithBlank, function(idx, state){
        var opt = ($(document.createElement('option'))).attr('value', state.id).html(state.name);
        if(selected == state.id){
          opt.prop('selected', true);
        }
        stateSelect.append(opt);
      });
      stateInput.hide().prop('disabled', true);
      countryStates.showStateElement(statePara);
      countryStates.showStateSelects(stateSelect, stateSelect2);
    } else {
      countryStates.hideStateSelects(stateSelect, stateSelect2);
      countryStates.showStateElement(stateInput);
      if(!statesRequired){
        stateInput.val('');
      }
      statePara.toggle(!!statesRequired);
      stateInput.prop('disabled', !statesRequired);
      stateInput.removeClass('hidden');
    }
  },

  hideStateSelects: function(select, select2){
    select.prop('disabled', true);
    select.hide();
    select2.hide();
  },

  showStateSelects: function(select, select2){
    select.prop('disabled', false);
    countryStates.showStateElement(select);
    select.removeClass('hidden');
    select2.show();
  },

  showStateElement: function(element){
    // jQuery .show() makes an item display inline-block.
    // We need block to not break te layout.
    element.css('display', 'block');
  }
}
