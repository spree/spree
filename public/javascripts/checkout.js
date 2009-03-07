var regions = new Array('billing', 'shipping', 'shipping_method', 'creditcard', 'confirm_order');

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
  $('span#bcountry select').change(function() { $('input#hidden_bstate').val(''); update_state('b'); });
  $('span#scountry select').change(function() { $('input#hidden_sstate').val(''); update_state('s'); });
  get_states();

  $('#validate_billing').click(function() { if(validate_section('billing')) { submit_billing(); }});
  $('#validate_shipping').click(function() { if(validate_section('shipping')) { submit_shipping(); }});
  $('#select_shipping_method').click(function() { submit_shipping_method(); });  
  $('#confirm_payment').click(function() { if(validate_section('creditcard')) { confirm_payment(); }});
  $('form#checkout_form').submit(function() { return !($('div#confirm_order').hasClass('checkout_disabled')); }); 
  // indicates order is ready to be processed (as opposed to simply updated)
  $("div#creditcard div.inner").hide(function() { $("input#final_answer").attr("value", ""); });
  $("div#creditcard div.inner").show(function() { $("input#final_answer").attr("value", "yes"); });  
})

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
  var selected = $('span#' + region + 'country :child :selected').html();
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
  $('span#' + region + 'state select, span#' + region + 'state input').addClass('required').attr('name', name).attr('id', id).val($('input#hidden_' + region + 'state').val()); 
  $('span#' + region + 'state select, span#' + region + 'state input').change(function() {
    $('input#hidden_' + region + 'state').val($(this).val());
  });
};

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

var shift_to_region = function(active) {
  var found = 0;
  for(var i=0; i<regions.length; i++) {
    if(!found) {
      if(active == regions[i]) {
        $('div#' + regions[i] + ' h2').unbind('click').css('cursor', 'default');
        $('div#' + regions[i] + ' div.inner').show('fast');
        $('div#' + regions[i]).removeClass('checkout_disabled');
        found = 1;
      }
      else {
        $('div#' + regions[i] + ' h2').unbind('click').css('cursor', 'pointer').click(function() {shift_to_region($(this).parent().attr('id'));});
        $('div#' + regions[i] + ' div.inner').hide('fast');
      }
    } else {
      $('div#' + regions[i] + ' h2').unbind('click').css('cursor', 'default');
      $('div#' + regions[i] + ' div.inner').hide('fast');
      $('div#' + regions[i]).addClass('checkout_disabled');
    }
  }
  return;
};

var submit_billing = function() {
  shift_to_region('shipping');
  build_address('Billing Address', 'b');
  return;
};

var build_address = function(title, region) {
  var address = '<h3>' + title + '</h3>';
  address += $('p#' + region + 'fname input').val() + ' ' + $('p#blname input').val() + '<br />';
  address += $('p#' + region + 'address input').val() + '<br />';
  if($('p#' + region + 'address2').val() != '') {
    address += $('p#' + region + 'address2').val() + '<br />';
  }
  address += $('p#' + region + 'city input').val() + ', ';
  if($('span#' + region + 'state input').length > 0) {
    address += $('span#' + region + 'state input').val();
  } else {
    address += $('span#' + region + 'state :selected').html();
  }
  address += ' ' + $('p#' + region + 'zip input').val() + '<br />';
  address += $('p#' + region + 'country :selected').html() + '<br />';
  address += $('p#' + region + 'phone input').val();
  $('div#' + region + 'display').html(address);
  return;
};

var submit_shipping = function() {
  $('div#methods :child').remove();
  $('div#methods').append($(document.createElement('img')).attr('src', '/images/ajax_loader.gif').attr('id', 'shipping_loader'));
  // Save what we have so far and get the list of shipping methods via AJAX
  $.ajax({
    type: "POST",
    url: 'complete',                                 
    beforeSend : function (xhr) {
      xhr.setRequestHeader('Accept-Encoding', 'identity');
    },      
    dataType: "json",
    data: "{form: '" + $('#checkout_form').serialize() + "'}",
    success: function(json) {  
      update_shipping_methods(json.available_methods); 
    },
    error: function (XMLHttpRequest, textStatus, errorThrown) {
      // TODO - put some real error handling in here
      $("#error").html(XMLHttpRequest.responseText);
    }
  });  
  shift_to_region('shipping_method');
  build_address('Shipping Address', 's');
  return;
};
                     
var submit_shipping_method = function() {
  //TODO: Move to validate_section('shipping_method'), but must debug how to validate radio buttons
  var valid = false;
  $('div#methods :child input').each(function() {
    if($(this).attr('checked')) {
      valid = true;
    }
  });
  if(valid) {
    // Save what we have so far and get the updated order totals via AJAX
    $.ajax({
      type: "POST",
      url: 'complete',                                 
      beforeSend : function (xhr) {
        xhr.setRequestHeader('Accept-Encoding', 'identity');
      },      
      dataType: "json",
      data: "{form: '" + $('#checkout_form').serialize() + "'}",
      success: function(json) {  
        update_confirmation(json.order); 
      },
      error: function (XMLHttpRequest, textStatus, errorThrown) {
        // TODO - put some real error handling in here
        //$("#error").html(XMLHttpRequest.responseText);
      }
    });  
    shift_to_region('creditcard');
  } else {
    var p = document.createElement('p');
    $(p).append($(document.createElement('label')).addClass('error').html('Please select a shipping method').css('width', '300px').css('top', '0px'));
    $('div#methods').append(p);
  }
}; 

var update_shipping_methods = function(methods) {
  $(methods).each( function(i) {
    $('div$methods img#shipping_loader').remove();
    var p = document.createElement('p');
    var s = this.name + ' ' + this.rate;
    $(p).append($(document.createElement('input'))
                .attr('id', s)
                .attr('type', 'radio')
                .attr('name', 'method_id')
                .attr(1 == $(methods).length ? 'checked' : 'notchecked', 'foo')
                .val(this.id)
                );
    $(p).append($(document.createElement('label'))
                .attr('for', s)
                .html(s)
                .css('top', '-1px'));
    $('div#methods').append(p);
  });
  $('div#methods input:first').attr('validate', 'required:true');
  return;
}                                     

var update_confirmation = function(order) {
  $('span#order_total').html(order.order_total);
  $('span#ship_amount').html(order.ship_amount);
  $('span#tax_amount').html(order.tax_amount);                                  
  $('span#ship_method').html(order.ship_method);                                    
}

var confirm_payment = function() {
  shift_to_region('confirm_order');
};
