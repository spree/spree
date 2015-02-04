// Attach a 'js-country' class to country select wrapper
// Attach a 'js-state' class to the state select wrapper
// Now the states will be refreshed as the country changes.

$(document).ready(function () {
  $('.js-country select').on('change', function () {
    var $parent = $(this).parents('form');
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
  return $('.js-country select', $parent).val();
}

function buildStatesSelect(data, $parent){
  var states = data.states;
  var statesRequired = data.states_required;

  var statePara = $('.js-state', $parent);
  var stateSelect = statePara.find('select');
  var stateInput = statePara.find('input');
  var stateSpanRequired = statePara.find('[id$="state-required"]');

  if(states.length > 0){
    var selected = parseInt(stateSelect.val());
    stateSelect.html('');
    var statesWithBlank = [{ name: '', id: ''}].concat(states);
    $.each(statesWithBlank, function(idx, state){
      var opt = ($(document.createElement('option'))).attr('value', state.id).html(state.name);
      if(selected == state.id){
        opt.prop('selected', true);
      }
      stateSelect.append(opt);
    });

    stateSelect.prop('disabled', false).show();
    stateInput.hide().prop('disabled', true);
    statePara.show();
    stateSpanRequired.show();
    if(statesRequired){
      stateSelect.addClass('required');
    }
    stateSelect.removeClass('hidden');
    stateInput.removeClass('required');
  } else {
    stateSelect.hide().prop('disabled', true);
    stateInput.show();
    if(statesRequired){
      stateSpanRequired.show();
      stateInput.addClass('required');
    } else {
      stateInput.val('');
      stateSpanRequired.hide();
      stateInput.removeClass('required');
    }
    statePara.toggle(!!statesRequired);
    stateInput.prop('disabled', !statesRequired);
    stateInput.removeClass('hidden');
    stateSelect.removeClass('required');
  }
}
