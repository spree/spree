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
