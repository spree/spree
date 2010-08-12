//On page load 
// TODO - remove nonconflict stuff once prototype is gone for good
var $j = jQuery.noConflict();

replace_ids = function(s){
  var new_id = new Date().getTime();
  return s.replace(/NEW_RECORD/g, new_id);
}

$j(function() { 
  $j('a[id*=nested]').click(function() { 
    var template = $j(this).attr('href').replace(/.*#/, '');
    html = replace_ids(eval(template));
    $j('#ul-' + $j(this).attr('id')).append(html);
    update_remove_links(); 
  });  
  update_remove_links();
})   

var update_remove_links = function() {  
  $j('.remove').click(function() {
    $j(this).prevAll(':first').val(1);
    $j(this).parent().hide();
    return false;
  });  
};  
