//On page load 
replace_ids = function(s){
  var new_id = new Date().getTime();
  return s.replace(/NEW_RECORD/g, new_id);
}

jQuery(function() { 
  jQuery('a[id*=nested]').click(function() { 
    var template = jQuery(this).attr('href').replace(/.*#/, '');
    html = replace_ids(eval(template));
    jQuery('#ul-' + jQuery(this).attr('id')).append(html);
    update_remove_links(); 
  });  
  update_remove_links();
})   

var update_remove_links = function() {  
  jQuery('.remove').click(function() {
    jQuery(this).prevAll(':first').val(1);
    jQuery(this).parent().hide();
    return false;
  });  
};  
