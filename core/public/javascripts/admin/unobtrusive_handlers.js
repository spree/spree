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

});
