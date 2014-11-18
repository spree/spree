(function($) {
  "use strict";

  $.fn.tree = function() {
    return this.each(function() {
      var btn = $(this).children("a").first();
      var menu = $(this).children(".treeview-menu").first();
      var isActive = $(this).hasClass('active');

      // initialize already active menus
      if (isActive) {
        menu.show();
        btn.children(".glyphicon-chevron-left").first().removeClass("glyphicon-chevron-left").addClass("glyphicon-chevron-down");
      }
      // slide open or close the menu on link click
      btn.click(function(e) {
        e.preventDefault();
        if (isActive) {
          // slide up to close menu
          menu.slideUp();
          isActive = false;
          btn.children(".glyphicon-chevron-down").first().removeClass("glyphicon-chevron-down").addClass("glyphicon-chevron-left");
          btn.parent("li").removeClass("active");
        } else {
          // slide down to open menu
          menu.slideDown();
          isActive = true;
          btn.children(".glyphicon-chevron-left").first().removeClass("glyphicon-chevron-left").addClass("glyphicon-chevron-down");
          btn.parent("li").addClass("active");
        }
      });
    });
  };
}(jQuery));

$(document).ready(function(){
  $(".sidebar .treeview").tree();
});
