$(document).ready(function(){

  $(".select_properties_from_prototype").live("click", function(){
    $("#busy_indicator").show();
    var clicked_link = $(this);
    jQuery.ajax({ dataType: 'script', url: clicked_link.attr("href"), type: 'get',
        success: function(data){
          clicked_link.parent("td").parent("tr").hide(); 
          $("#busy_indicator").hide();
        }
    });
    return false;
  });


  jQuery('table.sortable').ready(function(){ 
    jQuery('table.sortable tbody').sortable(
      {
        handle: '.handle',
        update: function(event, ui) {
          $("#progress").show();
          positions = {};
          type = '';
          jQuery.each(jQuery('table.sortable tbody tr'), function(position, obj){
            reg = /(\w+_?)+_(\d+)/;
            parts = reg.exec(jQuery(obj).attr('id'));
            if (parts) { 
              positions['positions['+parts[2]+']'] = position;
              type = parts[1];
            }
          });
          jQuery.ajax({
            type: 'POST',
            dataType: 'script',
            url: type+'s/update_positions',
            data: positions,
            success: function(data){ $("#progress").hide(); }
          });
        }
      });
  });

});
