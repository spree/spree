//On page load
$(function() {        
  $('input#coupon-code').keydown(function(event) { if (event.keyCode == 13) { ajax_coupon(); } });
  $('#checkout_same_address').sameAddress();
  $('span#bcountry select').change(function() { update_state('b'); });
  $('span#scountry select').change(function() { update_state('s'); });
  get_states();
  $('input#checkout_creditcard_number').blur(set_card_validation);
  
  // hook up the continue buttons for each section
  for(var i=0; i < regions.length; i++) {     
    var section = regions[i];                          
    $('#continue_' + section).click(function() { eval( "continue_button(this);"); return false; });
    
    // enter key should be same as continue button (don't submit form though)
    $('#' + section + ' input').bind("keyup", section, function(e) {
      if(e.keyCode == 13) {      
        continue_section(e.data);
      }
    });
  }                          
  //disable submit
  $('div#checkout :submit').attr('disabled', 'disabled');
  $('div#checkout-summary :submit').attr('disabled', 'disabled');
      
  // hookup the radio buttons for registration
  $('#choose_register').click(function() { $('div#new_user').show(); $('div#guest_user, div#existing_user').hide(); }); 
  $('#choose_existing').click(function() { $('div#existing_user').show(); $('div#guest_user, div#new_user').hide(); });
  $('#choose_guest').click(function() { $('div#guest_user').show(); $('div#existing_user, div#new_user').hide(); });
  var reg_choice = $('input[name=choose_registration]:checked').val();
  if(reg_choice) {
    $('#choose_' + reg_choice).click(); 
  } else {
    $('#choose_register').attr('checked', true);
  }

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
      $("#shipping #"+ $(this).attr('id').replace('bill', 'shipment_attributes')).val($(this).val());
    })
    update_state('s');
  })
};

//Initial state mapper on page load
var state_mapper;
var get_states = function() {
  $('span#bcountry select').val($('input#hidden_bcountry').val());
  update_state('b');
  $('span#bstate :only-child').val($('input#hidden_bstate').val());
  $('span#scountry select').val($('input#hidden_scountry').val());
  update_state('s');
  $('span#sstate :only-child').val($('input#hidden_sstate').val());
};

// replace the :only child of the parent with the given html, and transfer
//   {name,id} attributes over, returning the new child
var chg_state_input_element = function (parent, html) {
  var errorlabel = parent.find('label');
  errorlabel.remove();
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
  if ($('span#' + region + 'state').length == 0) { 
    return;
  } 
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
  continue_section(button.id.substring(9));
};  

var continue_section = function(section) {
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
  if(region == 'shipping_method') { return true; }
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
  if (active != regions[0]) { $('div.flash.errors').remove(); }
  var found = 0;
  for(var i=0; i<regions.length; i++) {
    if(!found) {
      if(active == regions[i]) {
        $('div#' + regions[i] + ' h2').unbind('click').css('cursor', 'default');
        $('div#' + regions[i] + ' div.inner').show('fast');
        $('div#' + regions[i]).removeClass('checkout_disabled').removeClass('disabled').removeClass('completed');
        found = 1;
      }
      else {
        $('div#' + regions[i] + ' h2').unbind('click').css('cursor', 'pointer').click(function() {shift_to_region($(this).parent().attr('id'));});
        $('div#' + regions[i] + ' div.inner').hide('fast');
        $('div#' + regions[i]).addClass('disabled').addClass('completed');
      }
    } else {
      $('div#' + regions[i] + ' h2').unbind('click').css('cursor', 'default');
      $('div#' + regions[i] + ' div.inner').hide('fast');
      $('div#' + regions[i]).addClass('checkout_disabled').addClass('disabled').removeClass('completed');
    }
  }                                                                         
  if (active == 'confirmation') {
    // indicates order is ready to be processed (as opposed to simply updated)
    $("input#final_answer").attr("value", "yes");    
    $('#continue_confirmation').removeAttr('disabled', 'disabled'); 
    $('#post-final').removeAttr('disabled', 'disabled'); 
  } else {
    $("input#final_answer").attr("value", "");
    // disable form submit
    $('div#checkout :submit').attr('disabled', 'disabled');
  }
  return;
};

var submit_billing = function() {
  build_address('b');
  return true;
};

var build_address = function(region) {
  var address = "";
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
  $('div#' + region + 'display div').html(address);
  return;
};

var submit_shipping = function() {
  $('div#methods :child').remove();
  $('div#shipping_method div.error').hide();
  $('div#methods').append($(document.createElement('img')).attr('src', '/images/ajax_loader.gif').attr('id', 'shipping_loader'));
  // Save what we have so far and get the list of shipping methods via AJAX
  $.ajax({
    type: "POST",
    url: '../checkout',                                 
    beforeSend : function (xhr) {
      xhr.setRequestHeader('Accept-Encoding', 'identity');
    },
    dataType: "json",
    data: $('#checkout_form').serialize(),
    success: function(json) {  
      update_shipping_methods(json.available_methods); 
    },
    error: function (XMLHttpRequest, textStatus, errorThrown) {
      $('div#methods :child').remove();
      $('div#shipping_method div.error').show();
      return false;
    }
  });  
  build_address('s');
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
      url: '../checkout',                                 
      beforeSend : function (xhr) {
        xhr.setRequestHeader('Accept-Encoding', 'identity');
      },      
      dataType: "json",
      data: $('#checkout_form').serialize(),
      success: function(json) {  
        update_confirmation(json);
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
                .attr('name', 'checkout[shipment_attributes][shipping_method_id]')
                .val(this.id)
                .click(function() { $('div#methods input').attr('checked', ''); $(this).attr('checked', 'checked'); });
    if($(methods).length == 1) {
      i.attr('checked', 'checked');
    }
    var l = $(document.createElement('label'))
                .attr('for', this.id)
                .html(s);
    $('div#methods').append($(p).append(i).append(l));
  });
  $('div#methods input:first').attr('validate', 'required:true');
  return;
};                                     

var update_confirmation = function(order) {
  var textToInsert = '';
  var summaryText = '';
  
  for (var key in order.charges) {
    textToInsert  += '<tr><td colspan="3"><strong>' + key + '</strong></td><td class="total_display"><span>' + order.charges[key] + '</span></td>';
    summaryText  += '<tr><td>' + key + '</td><td>' + order.charges[key] + '</td>';
  }
  $('tbody#order-charges').html(textToInsert);          
  $('tbody#summary-order-charges').html(summaryText);  
    
  textToInsert = '';                               
  summaryText = '';
  for (var key in order.credits) {
    textToInsert  += '<tr><td colspan="3"><strong>' + key + '</strong></td><td class="total_display"><span>' + order.credits[key] + '</span></td>';
    summaryText  += '<tr><td>' + key + '</td><td>(' + order.credits[key] + ')</td>';
  }
  $('tbody#order-credits').html(textToInsert);    
  $('tbody#summary-order-credits').html(summaryText);    

  $('span#order_total').html(order.order_total);
  $('span#summary-order-total').html(order.order_total);
};

var update_summary = function(order) {
  var textToInsert = '';
  for (var key in order.charges) {
    textToInsert  += '<tr><td colspan="3"><strong>' + key + '</strong></td><td class="total_display"><span>' + order.charges[key] + '</span></td>';
  }
  $('tbody#summary-order-charges').html(textToInsert);  
  $('tbody#summary-order-credits').html(textToInsert);    
  $('span#summary-order-total').html(order.order_total);
};      

var submit_registration = function() {
  // no need to do any ajax, user is already logged in
  if ($('div#already_logged_in:hidden').size() == 0) return true;
  var register_method = $('input[name=choose_registration]:checked').val();
  
  $('div#registration_error').removeClass('error').html('');    

  if (register_method == 'existing') {
	ajax_login();
  }
  else if (register_method == 'register') {
	ajax_register();
  }
		
  return ($('div#registration_error').html() == "");  
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
    data: $('#checkout_form').serialize() + "&_method=post",
    success: function(result) {  
      if (result) {
        $('div#already_logged_in').show();
        $('div#register_or_guest').hide();
        update_addresses(result);
        update_login();
      } else {
        registration_error("Invalid username or password.");
      };
    },
    error: function (XMLHttpRequest, textStatus, errorThrown) {
      registration_error("Unable to perform login due to a server error.");
    }
  });  	
};

var ajax_register = function() {
  $.ajax({
    async: false,
    type: "POST",
    url: '/users',                                 
    beforeSend : function (xhr) {
      xhr.setRequestHeader('Accept-Encoding', 'identity');
    },      
    dataType: "json",
    data: $('#checkout_form').serialize() + "&_method=post",
    success: function(result) {  
      if (result == true) {
        $('div#already_logged_in').show();
        $('div#register_or_guest').hide();
        update_login();
      } else {                                         
        var error_msg = "Unable to register user";              
        for (var i=0; i < result.length; i++) {
          error_msg += "<br/>";
          error_msg += result[i][0] + ": " + result[i][1];
        }
        registration_error(error_msg);
      };
    },
    error: function (XMLHttpRequest, textStatus, errorThrown) {
      registration_error("Unable to register due to a server error.");    
    }
  });  	
};

var registration_error = function(error_message) {
  $('div#registration_error').addClass('error').html(error_message);
};

var submit_payment = function() {             
  return true;
};    

var submit_confirmation = function() {  
  //$('form').submit();
  $('#post-final').click();
};

// update login partial
var update_login = function() {
  $.ajax({
    url: '/user_session/login_bar',                                 
    beforeSend : function (xhr) {
      xhr.setRequestHeader('Accept-Encoding', 'identity');
    },      
    dataType: "html",
    success: function(result) {
      $("div#login-bar").html(result);
    },
    error: function (XMLHttpRequest, textStatus, errorThrown) {
      // TODO (maybe do nothing)
    }
  });  	
};



/* validating card details */

/* this info is held in an array to get a strict order on the tests in case of overlap
 * (original info taken from activemerchant, but a better reference seems to be 
 *   http://en.wikipedia.org/wiki/Credit_card_number - though there's nothing definitive?)
 * this info could be used to tell AM what the correct type is... (and remove the hook...?)
 * switch now identified as maestro
 * TODO: finish this list
 * (from AM_protx, extra - ELECTRON = /^(424519|42496[23]|450875|48440[6-8]|4844[1-5][1-5]|4917[3-5][0-9]|491880)\d{10}(\d{3})?$/
 */
var current_card_type = null;

var card_regexps 
   = [ 
       [ 'Visa Electron'      , /^(417500|(4917|4913|4508|4844)\d{2})\d{10}$/ ]
     , [ 'Visa'               , /^4\d{12}(\d{3})?$/                           ]
     , [ 'MasterCard'         , /^(5[1-5]\d{4}|677189)\d{10}$/                ]
  // , [ 'discover'           , /^(6011|65\d{2})\d{12}$/                      ]
     , [ 'American Express'   , /^(34|37)\d{13}$/                             ]
     , [ 'Diners Club'        , /^3(0[0-5]|[68]\d)\d{11}$/                    ]
     , [ 'JCB'                , /^35(2[89]|[3-8]\d)\d{12}$/                ]
     , [ 'Solo'               , /^(6767|6334)\d{12}(\d{2,3})?$/               ]
  // , [ 'dankort'            , /^5019\d{12}$/                                ]
     , [ 'Maestro'            , /^((5018|5020|5038|6304|6759|6761|4903|4905|4911|4936|6333|6759)\d{2}|564182|633100)\d{10,13}$/ ]
  // , [ 'forbrugsforeningen' , /^600722\d{10}$/                              ]
     , [ 'Laser'              , /^(6304|6706|6771|6709)\d{12,15}$/            ]
     ];

var card_type = function(number) {
  var name = null;
  $.each(card_regexps, function (i,e) {
    if (number.match(e[1])) {
      name = e[0];
      return false;
    }
  });
  return name;
};

var set_card_validation = function () {
  if ($("#checkout_creditcard_number").val().match(/^\s*$/)) {
    $('#card_type').hide();
    return;
  }
  current_card_type = card_type($("#checkout_creditcard_number").val());
  $('#card_type').show();
  $('#card_type #looks_like').hide();
  $('#card_type #unrecognized').hide();
  if (current_card_type == null) {
    $('#card_type #unrecognized').show();
    current_card_type = "unknown";   
  } else {
    $('#card_type #looks_like #type').html(current_card_type);
    $('#card_type #looks_like').show();
  }
  if (current_card_type.match(/unknown|maestro|solo|switch/i)) {
    $('p#maestro_extra').show('slow');
  } else {
    $('p#maestro_extra').hide('slow');
    $('p#maestro_extra input, p#maestro_extra select').val("")      // clear the values
  }
};

var ajax_coupon = function() {
  $.ajax({
    type: "POST",
    url: '../checkout',                                
    beforeSend : function (xhr) {
      xhr.setRequestHeader('Accept-Encoding', 'identity');        
      $('div#coupon-error').removeClass('error').html("");     
      $('img#coupon_busy_indicator').show();
    },      
    dataType: "json",   
    data: $('#checkout-summary-form').serialize(),    
    complete: function() { $('img#coupon_busy_indicator').hide(); },
    success: function(json) {  
      // TODO - create new div for coupon messages and provide feedback that it was accepted       
      update_confirmation(json);
    },
    error: function (XMLHttpRequest, textStatus, errorThrown) {
      $('div#coupon-error').addClass('error').html("Server Error: Unable to Process Coupon");
    }
  });  	
};
