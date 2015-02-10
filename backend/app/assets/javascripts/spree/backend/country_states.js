// Attach a 'js-country-states' class to a wrapper around both fields
// Attach a 'js-country' class to country select wrapper
// Attach a 'js-state' class to the state select wrapper
// Now the states will be refreshed as the country changes.

$(document).ready(function () {
  $('.js-country select').on('change', function () {
    var $parent = $(this).parents('.js-country-states');
    requestStates($parent);
  });
});

function requestStates($parent){
  var countryId = getCountryId($parent);

  $.ajax({
    type: 'GET',
    url: Spree.routes.states_search,
    data: {
      country_id: countryId
    }
  }).done(function (data) {
    buildStatesSelect(data, $parent);
  }).error(function (msg) {
    console.log(msg);
  });
}

function getCountryId($parent){
  return $('.js-country select.select2', $parent).val();
}

function buildStatesSelect(data, $parent){
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
    showStateElement(statePara);
    showStateSelects(stateSelect, stateSelect2);
  } else {
    hideStateSelects(stateSelect, stateSelect2);
    showStateElement(stateInput);
    if(!statesRequired){
      stateInput.val('');
    }
    statePara.toggle(!!statesRequired);
    stateInput.prop('disabled', !statesRequired);
    stateInput.removeClass('hidden');
  }
}

function hideStateSelects(select, select2){
  select.prop('disabled', true);
  select.hide();
  select2.hide();
}

function showStateSelects(select, select2){
  select.prop('disabled', false);
  showStateElement(select);
  select.removeClass('hidden');
  select2.show();
}

function showStateElement(element){
  // jQuery .show() makes an item display inline-block.
  // We need block to not break te layout.
  element.css('display', 'block');
}
