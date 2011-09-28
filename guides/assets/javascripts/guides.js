$(document).ready(function() {
  $('#guidesMenu').click(function(e) {
    e.preventDefault();

    var menu_button = $(this);
    var menu = $("#guides")

    if(menu.is(':visible')){
      menu.hide();
      $('#guidesArrow').html("&#9656;");
    }else{

    pos = menu_button.offset();
    button_width = menu_button.width();
    menu_width = menu.width();

    menu.css({ "left": (pos.left - (menu_width - button_width) + 20) + "px", "top": (pos.top + 40)+ "px" }).show();

      $('#guidesArrow').html("&#9662;");

    // if (document.getElementById('guides').style.display == "none") {
    //   document.getElementById('guides').style.display = "block";
    //   document.getElementById('guidesArrow').innerHTML = "&#9662;";
    // } else {
    //   document.getElementById('guides').style.display = "none";
    //   document.getElementById('guidesArrow').innerHTML = "&#9656;";
    // }

    }

  })

});
