//On page load
$(function() {  
  $('#checkout_same_address').sameAddress();
  $('span#bcountry select').change(function() { update_state('b'); });
  $('span#scountry select').change(function() { update_state('s'); });
  get_states();
  
  // hook up the continue buttons for each section
  for(var i=0; i < regions.length; i++) {                               
    $('#continue_' + regions[i]).click(function() { eval( "continue_button(this);") });   
  }                           

	// hookup the radio buttons for registration
	$('#choose_register').click(function() { $('div#new_user').show(); $('div#guest_user, div#existing_user').hide(); });
	$('#choose_existing').click(function() { $('div#existing_user').show(); $('div#guest_user, div#new_user').hide(); });
	$('#choose_guest').click(function() { $('div#guest_user').show(); $('div#existing_user, div#new_user').hide(); });	

  // activate first region
  shift_to_region(regions[0]); 
})

jQuery.fn.sameAddress = function() {
  this.click(function() {
    if(!$(this).attr('checked')) {
      //Clear ship values?
      return;
    }
    $('input#hidden_sstate').val($('input#hidden_bstate').val());
    $("#billing input, #billing select").each(function() {
      $("#shipping #"+ $(this).attr('id').replace('bill', 'ship')).val($(this).val());
    })
    update_state('s');
  })
}

//Initial state mapper on page load
var state_mapper;
var get_states = function() {
  $.getJSON('/states.js', function(json) {
    state_mapper = json;
    $('span#bcountry select').val($('input#hidden_bcountry').val());
    update_state('b');
    $('span#bstate :only-child').val($('input#hidden_bstate').val());
    $('span#scountry select').val($('input#hidden_scountry').val());
    update_state('s');
    $('span#sstate :only-child').val($('input#hidden_sstate').val());
  });
};

// replace the :only child of the parent with the given html, and transfer
//   {name,id} attributes over, returning the new child
var chg_state_input_element = function (parent, html) {
  var child = parent.find(':only-child');
  var name = child.attr('name');
  var id = child.attr('id');
  //Toggle back and forth between id and name
  if(html.attr('type') == 'text' && child.attr('type') != 'text') {
    name = name.replace('_id', '_name');
    id = id.replace('_id', '_name');
  } else if(html.attr('type') != 'text' && child.attr('type') == 'text') {
    name = name.replace('_name', '_id');
    id = id.replace('_name', '_id');
  }
  html.addClass('required')
      .attr('name', name)
      .attr('id',   id);
  child.remove();		// better as parent-relative?
  parent.append(html);
  return html;
};


// TODO: better as sibling dummy state ?
// Update the input method for address.state 
var update_state = function(region) {
  var country        = $('span#' + region + 'country :only-child').val();
  var states         = state_mapper[country];
  var hidden_element = $('input#hidden_' + region + 'state');

  var replacement;
  if(states) {
    // recreate state selection list
    replacement = $(document.createElement('select'));
    var states_with_blank = [["",""]].concat(states);
    $.each(states_with_blank, function(pos,id_nm) {
      var opt = $(document.createElement('option'))
                .attr('value', id_nm[0])
                .html(id_nm[1]);
      replacement.append(opt);
      if (id_nm[0] == hidden_element.val()) { opt.attr('selected', 'true') }
        // set this directly IFF the old value is still valid
    });
  } else {
    // recreate an input box
    replacement = $(document.createElement('input'));
    if (! hidden_element.val().match(/^\d+$/)) { replacement.val(hidden_element.val()) }
  }

  chg_state_input_element($('span#' + region + 'state'), replacement);
  hidden_element.val(replacement.val());

  // callback to update val when form object is changed
  // This is only needed if we want to preserve state when someone refreshes the checkout page
  // Or... if someone changes between countries with no given states
  replacement.change(function() {
    $('input#hidden_' + region + 'state').val($(this).val());
  });
};       

var continue_button = function(button) {
  var section = button.id.substring(9);
  // validate
  if (!validate_section(section)) { return; };
  // submit
  var success = eval("submit_" + section + "();");
  if (!success) { return; }
  // move to next section      
  for(var i=0; i<regions.length; i++) {
    if (regions[i] == section) {
      if (i == (regions.length - 1)) { break; };
      shift_to_region(regions[i+1]);
    }
  }
  
};

var validate_section = function(region) {
  var validator = $('form#checkout_form').validate();
  var valid = true;
  $('div#' + region + ' input:visible, div#' + region + ' select:visible, div#' + region + ' textarea:visible').each(function() {
    if(!validator.element(this)) {
      valid = false;
    }
  });
  return valid;
};

var shift_to_region = function(active) {
  $('div#flash-errors').remove();  
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
  if (active == 'confirmation') {
    $("input#final_answer").attr("value", "yes");    
  } else {
    // indicates order is ready to be processed (as opposed to simply updated)
    $("input#final_answer").attr("value", "");    
  }
  return;
};

var submit_billing = function() {
  build_address('Billing Address', 'b');
  return true;
};

var build_address = function(title, region) {
  var address = '<h3>' + title + '</h3>';
  address += $('p#' + region + 'fname input').val() + ' ' + $('p#' + region + 'lname input').val() + '<br />';
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
    url: 'checkout',                                 
    beforeSend : function (xhr) {
      xhr.setRequestHeader('Accept-Encoding', 'identity');
    },      
    dataType: "json",
    data: $('#checkout_form').serialize(),
    success: function(json) {  
      update_shipping_methods(json.available_methods); 
    },
    error: function (XMLHttpRequest, textStatus, errorThrown) {
      // TODO - put some real error handling in here
      $("#error").html(XMLHttpRequest.responseText); 
      return false;
    }
  });  
  build_address('Shipping Address', 's');
  return true;
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
      url: 'checkout',                                 
      beforeSend : function (xhr) {
        xhr.setRequestHeader('Accept-Encoding', 'identity');
      },      
      dataType: "json",
      data: $('#checkout_form').serialize(),
      success: function(json) {  
        update_confirmation(json.order); 
      },
      error: function (XMLHttpRequest, textStatus, errorThrown) {
        // TODO - put some real error handling in here
        //$("#error").html(XMLHttpRequest.responseText);           
        return false;
      }
    });  
    return true;
  } else {
    var p = document.createElement('p');
    $(p).append($(document.createElement('label')).addClass('error').html('Please select a shipping method').css('width', '300px').css('top', '0px'));
    $('div#methods').append(p);
    return false;
  }
}; 

var update_shipping_methods = function(methods) {
  $(methods).each( function(i) {
    $('div$methods img#shipping_loader').remove();
    var p = document.createElement('p');
    var s = this.name + ' ' + this.rate;
    var i = $(document.createElement('input'))
                .attr('id', this.id)
                .attr('type', 'radio')
                .attr('name', 'method_id')
                .val(this.id)
                .click(function() { $('div#methods input').attr('checked', ''); $(this).attr('checked', 'checked'); });
    if($(methods).length == 1) {
      i.attr('checked', 'checked');
    }
    var l = $(document.createElement('label'))
                .attr('for', s)
                .html(s)
                .css('top', '-1px')
                .css('width', '300px');
    $('div#methods').append($(p).append(i).append(l));
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

var submit_registration = function() {
  $('div#registration_error').removeClass('error').html("");    

	// we assume the user wants to login if they supply both a username and password
	if ($('#user_session_login').val() != "" && $('#user_session_password').val() != "") {
		ajax_login();
		return ($('div#registration_error:hidden').size() == 1);
	}
		
  return ($('div#registration_error:hidden').size() == 1);  
};

var ajax_login = function() {
  $.ajax({
		async: false,
    type: "POST",
    url: '/user_session',                                 
    beforeSend : function (xhr) {
      xhr.setRequestHeader('Accept-Encoding', 'identity');
    },      
    dataType: "json",
    data: $('#checkout_form').serialize(),
    success: function(result) {  
      if (result) {
				$('div#already_logged_in').show();
				$('div#register_or_guest').hide();
        // todo
      } else {
        registration_error("Invalid username or password.");
      };
    },
    error: function (XMLHttpRequest, textStatus, errorThrown) {
      // TODO - put some real error handling in here
      $("#ajax_error").html(XMLHttpRequest.responseText);           
    }
  });  	
}

var registration_error = function(error_message) {
  $('div#registration_error').addClass('error').html(error_message);
}

var submit_payment = function() {             
  return true;
};    

var submit_confirmation = function() {  
  return true;
};
