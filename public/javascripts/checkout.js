$(document).ajaxSend(function(event, request, settings) {
  if (typeof(AUTH_TOKEN) == "undefined") return;
  // settings.data is a serialized string like "foo=bar&baz=boink" (or null)
  settings.data = settings.data || "";
  settings.data += (settings.data ? "&" : "") + "authenticity_token=" + encodeURIComponent(AUTH_TOKEN);
});

// public/javascripts/application.js
jQuery.ajaxSetup({ 
  'beforeSend': function(xhr) {xhr.setRequestHeader("Accept", "text/javascript")}
})

jQuery.fn.submitWithAjax = function() {
  this.change(function() {
    $.post('select_country', $(this).serialize(), null, "script");
    return false;
  })
  return this;
};

$("#shipping_fieldset input, #shipping_fieldset select").each(function() {
    $("#billing_fieldset #"+ $(this).attr("id").replace(/shipping/, "billing")).val($(this).val());
});
                                  
jQuery.fn.sameAddress = function() {
  this.click(function() {
    if(!$(this).attr('checked')) {
      //Clear ship values?
      return;
    }
    $('td#scountry select').val($('td#bcountry select').val());
    update_state('s');
    $("#billing input, #billing select").each(function() {
      $("#shipping #"+ $(this).attr('id').replace('bill', 'ship')).val($(this).val());
    })
    //For some reason this isn't getting picked up from above.. Debug later
    $('#sstate :child').val($('#bstate :child').val());
  })
}

//On page load
$(function() {  
  //$("#checkout_presenter_bill_address_country_id").submitWithAjax();  
  $('#same_address').sameAddress();
  $('td#bcountry select').change(function() { update_state('b'); });
  $('td#scountry select').change(function() { update_state('s'); });
  get_states();
  $('div#validate_billing').css('cursor', 'pointer').click(function() { validate_section('billing'); });
  $('div#validate_shipping').css('cursor', 'pointer').click(function() { validate_section('shipping'); });
  $('div#validate_creditcard').css('cursor', 'pointer').click(function() { validate_section('creditcard'); });
})

var validate_section = function(region) {
	var validator = $('form#checkout_form').validate();
	var valid = true; 
	$('div#' + region + ' input, div#' + region + ' select, div#' + region + ' textarea').each(function() {
		if(!validator.element(this)) {
			valid = false;
		}
	});
};

//Initial state mapper on page load
var state_mapper;
var get_states = function() {
  $.getJSON('/javascripts/states.js', function(json) {
    state_mapper = json;
    $('td#bcountry select').val($('[name=submit_bcountry]').val());
    update_state('b');
    $('td#bstate :child').val($('[name=submit_bstate]').val());
    $('td#scountry select').val($('[name=submit_scountry]').val());
    update_state('s');
    $('td#sstate :child').val($('[name=submit_sstate]').val());
  });
};

//Update state input / select
var update_state = function(region) {
  var name = $('td#' + region + 'state :child').attr('name');
  var id = $('td#' + region + 'state :child').attr('id');
  $('td#' + region + 'state :child').remove();
  var match;
  var selected = $('td#' + region + 'country :child :selected').html()
  $.each(state_mapper.maps, function(i, item) {
    if(selected == item.country) {
      match = item.states;
    }
  });
  if(match) {
    $('td#' + region + 'state').append($(document.createElement('select')));
    $.each(match, function(i, item) {
      $('td#' + region + 'state select').append($(document.createElement('option')).attr('value', item.value).html(item.text));
    });
  } else {
    $('td#' + region + 'state').append($(document.createElement('input')));
  }
  $('td#' + region + 'state select, td#' + region + 'state input').addClass('required').attr('name', name).attr('id', id);
};
