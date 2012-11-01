//On page load 
replace_ids = function(s){
  var new_id = new Date().getTime();
  return s.replace(/NEW_RECORD/g, new_id);
}

$(function() {
  $('a[id*=nested]').click(function() { 
    var template = $(this).attr('href').replace(/.*#/, '');
    html = replace_ids(eval(template));
    $('#ul-' + $(this).attr('id')).append(html);
    update_remove_links();
  });  
  update_remove_links();
})   

var update_remove_links = function() {
  $('.remove').click(function() {
    $(this).prevAll(':first').val(1);
    $(this).parent().hide();
    return false;
  });
};
