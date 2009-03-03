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
    $('span#scountry select').val($('span#bcountry select').val());
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
  $('#checkout_presenter_same_address').sameAddress();
  $('span#bcountry select').change(function() { update_state('b'); });
  $('span#scountry select').change(function() { update_state('s'); });
  get_states();
  $('div#validate_billing').css('cursor', 'pointer').click(function() { if(validate_section('billing')) { submit_billing(); }});
  $('div#validate_shipping').css('cursor', 'pointer').click(function() { if(validate_section('shipping')) { submit_shipping(); }});
  $('div#billing h2').click(function() { check_billing(); });
  $('div#shipping h2').click(function() { check_shipping(); });
  $('div#creditcard h2').click(function() { check_creditcard(); });  
  $('form').submit(function() { return submit_form(); });
})

var check_billing = function() {
  $('div#creditcard div.inner, div#shipping div.inner').hide();
  $('div#creditcard, div#shipping').addClass('checkout_disabled');
  $('div#billing div.inner').show();
}

var check_shipping = function() {
  if($('div#shipping').attr('class') == 'checkout_disabled') {
    if(validate_section('billing')) {
      submit_billing();
    }
  } else {
    $('div#creditcard div.inner').hide();
    $('div#creditcard').addClass('checkout_disabled');
    $('div#shipping div.inner').show();
  }
  return;
}

var check_creditcard = function() {
  if($('div#creditcard').attr('class') == 'checkout_disabled') {
    if($('div#shipping').attr('class') == 'checkout_disabled') {
      if(validate_section('billing')) {
        submit_billing();
      }
    }
    if(validate_section('shipping')) {
      submit_shipping();
    }
  }
}

var submit_billing = function() {
  //INSIDE SUCCESS OF VALIDATION
  $('div#billing div.inner').hide();
  $('div#shipping div.inner').show();
  $('div#shipping').removeClass('checkout_disabled');
  //OTHERWISE ADD ERROR
  return;
}
var submit_shipping = function() {
  //INSIDE SUCCESS OF VALIDATION
  $('div#shipping div.inner').hide();
  $('div#creditcard div.inner').show();
  //OTHERWISE ADD ERROR
  return;
}

var validate_section = function(region) {
  var validator = $('form#checkout_form').validate();
  var valid = true; 
  $('div#' + region + ' input, div#' + region + ' select, div#' + region + ' textarea').each(function() {
    if(!validator.element(this)) {
      valid = false;
    }
  });
  return valid;
};

//Initial state mapper on page load
var state_mapper;
var get_states = function() {
  $.getJSON('/javascripts/states.js', function(json) {
    state_mapper = json;
    $('span#bcountry select').val($('[name=submit_bcountry]').val());
    update_state('b');
    $('span#bstate :child').val($('[name=submit_bstate]').val());
    $('span#scountry select').val($('[name=submit_scountry]').val());
    update_state('s');
    $('span#sstate :child').val($('[name=submit_sstate]').val());
  });
};

//Update state input / select
var update_state = function(region) {
  var name = $('span#' + region + 'state :child').attr('name');
  var id = $('span#' + region + 'state :child').attr('id');
  $('span#' + region + 'state :child').remove();
  var match;
  var selected = $('span#' + region + 'country :child :selected').html()
  $.each(state_mapper.maps, function(i, item) {
    if(selected == item.country) {
      match = item.states;
    }
  });
  if(match) {
    $('span#' + region + 'state').append($(document.createElement('select')));
    $.each(match, function(i, item) {
      $('span#' + region + 'state select').append($(document.createElement('option')).attr('value', item.value).html(item.text));
    });
  } else {
    $('span#' + region + 'state').append($(document.createElement('input')));
  }
  $('span#' + region + 'state select, span#' + region + 'state input').addClass('required').attr('name', name).attr('id', id);
};
 
                     
var submit_form = function() {
  return false;
};