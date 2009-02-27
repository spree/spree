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
    var elem = $(this);
    $("#billing_fieldset #"+ 
        elem.attr("id").replace(/shipping/, "billing")).val(elem.val());
});
                                  
jQuery.fn.sameAddress = function() {
  this.click(function() {
    $("#billing :input, #billing select").each(function() {    
      var elem = $(this);
      $("#shipping #"+ elem.attr("id").replace(/bill/, "ship")).val(elem.val());
    })
  })
}


$(function() {  
  $("#checkout_presenter_bill_address_country_id").submitWithAjax();  
  $('#same_address').sameAddress();
  //$("#new_review").submitWithAjax();
})