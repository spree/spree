$(document).ready(function($){

  $('input#checkout_use_billing').click(function() {
    show_billing(!this.checked);
  });

  var show_billing = function(show) {
    if(show) {
      $('#shipping .inner').show();
      $('#shipping .inner select').removeAttr('disabled');
      $('#shipping .inner input').removeAttr('disabled');

      //only want to enable relevant field
      if(get_states('s')){
        $('span#sstate input').attr('disabled', true);
      }else{
        $('span#sstate select').attr('disabled', true);
      }

    } else {
      $('#shipping .inner').hide();
      $('#shipping .inner select').attr('disabled', true);
      $('#shipping .inner input').attr('disabled', true);
    }
  }

  var get_states = function(region){
    var country        = $('span#' + region + 'country :only-child').val();
    return state_mapper[country];
  }

  var update_state = function(region) {
    var states         = get_states(region);

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
      state_select.removeAttr('disabled').show();;
      state_input.hide().attr('disabled', true);

    } else {
      state_input.removeAttr('disabled').show();
      state_select.hide().attr('disabled', true);
    }

  };

  // Show fields for the selected payment method
  $("input[type='radio'][name='checkout[payments_attributes][][payment_method_id]']").click(function(){
    var payment_method_li = $('#payment-methods li:visible');
    payment_method_li.hide();
    payment_method_li.find('input,select').attr('disabled', true);

    if(this.checked){
      payment_method_li = $('#payment_method_'+this.value);
      payment_method_li.find('input,select').removeAttr('disabled');
      payment_method_li.show();
    }
  }).triggerHandler('click');

  $('span#bcountry select').change(function() { update_state('b'); });
  $('span#scountry select').change(function() { update_state('s'); });

  update_state('b');
  update_state('s');
  show_billing(!$('input#checkout_use_billing').attr('checked'));

  $('form.edit_checkout').submit(function() {
    var form = $(this);
    if(form.valid()){
      form.find(':submit, :image').attr('disabled', true).removeClass('primary').addClass('disabled');
    }else{
      return false;
    }
  });


});
