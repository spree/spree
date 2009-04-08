/* Address Book Manipulation */
$(function() {
  get_states();
  $('span#country select').change(function() { update_state(''); });
  $('#save_address').click(function() { $('form#address_form').validate(); });
});

var state_mapper;
var get_states = function() {
  $.getJSON('/states.js', function(json) {
    state_mapper = json;
    $('span#country select').val($('input#hidden_country').val());
    update_state('');
    $('span#state :only-child').val($('input#hidden_state').val());
  });
};

var update_state = function(region) {
  var country        = $('span#' + region + 'country :only-child').val();
  var states         = state_mapper[country];
  var hidden_element = $('input#hidden_' + region + 'state');

  var replacement;
  if(states) {
    replacement = $(document.createElement('select'));
    var states_with_blank = [["",""]].concat(states);
    $.each(states_with_blank, function(pos,id_nm) {
      var opt = $(document.createElement('option'))
                .attr('value', id_nm[0])
                .html(id_nm[1]);
      replacement.append(opt);
      if (id_nm[0] == hidden_element.val()) { opt.attr('selected', 'true') }
    });
  } else {
    replacement = $(document.createElement('input'));
    if (! hidden_element.val().match(/^\d+$/)) { replacement.val(hidden_element.val()) }
  }
  chg_state_input_element($('span#' + region + 'state'), replacement);
  hidden_element.val(replacement.val());
  replacement.change(function() {
    $('input#hidden_' + region + 'state').val($(this).val());
  });
};

var chg_state_input_element = function (parent, html) {
  var child = parent.find(':only-child');
  var name = child.attr('name');
  var id = child.attr('id');
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
  child.remove();               // better as parent-relative?
  parent.append(html);
  return html;
};
