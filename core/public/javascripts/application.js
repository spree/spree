jQuery(function($){

  // Remove an item from the cart by setting its quantity to zero and posting the update form
  $('form#updatecart a.delete').show().click(function(){
    $(this).parents('tr').find('input.line_item_quantity').val(0);
    $(this).parents('form').submit();
    return false;
  });

  // Address forms code
  $('form.address_form').validate();

  var get_states = function(region){
    var country = $('p#' + region + 'country span#' + region + 'country :only-child').val();
    return state_mapper[country];
  }

  var update_state = function(region) {
    var states = get_states(region);

    var state_select = $('span#' + region + 'state select');
    var state_input = $('span#' + region + 'state input');

    if(states) {
      var selected = state_select.val();
      state_select.html('');
      var states_with_blank = [["",""]].concat(states);
      $.each(states_with_blank, function(pos,id_nm) {
        var opt = $(document.createElement('option'))
                  .attr('value', id_nm[0])
                  .html(id_nm[1]);
        if(selected==id_nm[0]){
          opt.attr('selected', 'selected');
        }
        state_select.append(opt);
      });
      state_select.removeAttr('disabled').show();
      state_input.hide().attr('disabled', 'disabled');
    } else {
      state_input.removeAttr('disabled').show();
      state_select.hide().attr('disabled', 'disabled');
    }
  };

  $('p#bcountry span#bcountry select').change(function() { update_state('b'); });
  $('p#scountry span#scountry select').change(function() { update_state('s'); });
  update_state('b');
  update_state('s');

  $('input.use_billing_address').click(function() {
    if($(this).is(':checked')) {
      $('#shipping .inner input, #shipping .inner select, #shipping .inner label, #shipping .inner .req').hide();
      $('#shipping .inner input, #shipping .inner select').attr('disabled', 'disabled');
    } else {
      $('#shipping .inner input, #shipping .inner select, #shipping .inner label, #shipping .inner .req').show();
      $('#shipping .inner input, #shipping .inner select').removeAttr('disabled', 'disabled');

      //only want to enable relevant field
      if(get_states('s')){
        $('span#sstate input').hide().attr('disabled', 'disabled');
      }else{
        $('span#sstate select').hide().attr('disabled', 'disabled');
      }

    }
  }).triggerHandler('click');

  // Show fields for the selected payment method
  $("input[type='radio'][name='order[payments_attributes][][payment_method_id]']").click(function(){
    $('#payment-methods li').hide();
    if(this.checked){ $('#payment_method_'+this.value).show(); }
  }).triggerHandler('click');

  $('form.edit_checkout').submit(function() {
    $(this).find(':submit, :image').attr('disabled', true).removeClass('primary').addClass('disabled');
  });

});
