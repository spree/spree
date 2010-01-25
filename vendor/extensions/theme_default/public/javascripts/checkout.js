jQuery(document).ready(function($){

  $('input#checkout_use_billing').click(function() {
    show_billing(!this.checked);
  });

  var show_billing = function(show) {
    if(show) {
      $('#shipping .inner').show();
      $('#shipping .inner input').removeAttr('disabled', 'disabled');
      $('#shipping .inner select').removeAttr('disabled', 'disabled');
    } else {
      $('#shipping .inner').hide();
      $('#shipping .inner input').attr('disabled', 'disabled');
      $('#shipping .inner select').attr('disabled', 'disabled');
    }
  }

  var update_state = function(region) {
    var country        = $('span#' + region + 'country :only-child').val();
    var states         = state_mapper[country];

    var state_select = $('span#' + region + 'state select');
    var state_input = $('span#' + region + 'state input');

    if(states) {
      state_select.html('');
      var states_with_blank = [["",""]].concat(states);
      $.each(states_with_blank, function(pos,id_nm) {
        var opt = $(document.createElement('option'))
                  .attr('value', id_nm[0])
                  .html(id_nm[1]);
        state_select.append(opt);
      });
      state_select.removeAttr('disabled').show();;
      state_input.hide().attr('disabled', 'disabled');

    } else {
      state_input.removeAttr('disabled').show();
      state_select.hide().attr('disabled', 'disabled');
    }

  };

  jQuery(document).ready(function(){
    $('span#bcountry select').change(function() { update_state('b'); });
    $('span#scountry select').change(function() { update_state('s'); });
    show_billing(!$('input#checkout_use_billing').attr('checked'));
    update_state('b');
    update_state('s');
  });

});
