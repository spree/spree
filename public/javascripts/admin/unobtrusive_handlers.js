$(document).ready(function(){

  $(".select_properties_from_prototype").live("click", function(){
    $("#busy_indicator").show();
    var clicked_link = $(this);
    $.post(clicked_link.attr("href"), {'authenticity_token': AUTH_TOKEN},
        function(data, textStatus){
          clicked_link.parent("td").parent("tr").hide();
        },
        "script");
    $("#busy_indicator").hide();
    return false;
  });

});
