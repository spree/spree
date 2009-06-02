onchange : function (NODE, TREE_OBJ) { 
  var $this = $(NODE).is("li") ? $(NODE) : $(NODE).parent();
  if($this.children("a.unchecked").size() == 0) {
    TREE_OBJ.container.find("a").addClass("unchecked");
  }
  $this.children("a").removeClass("clicked");
  if($this.children("a").hasClass("checked")) {
    $this.find("li").andSelf().children("a").removeClass("checked").removeClass("undetermined").addClass("unchecked");
    var state = 0;
  }
  else {
    $this.find("li").andSelf().children("a").removeClass("unchecked").removeClass("undetermined").addClass("checked");
    var state = 1;
  }
  $this.parents("li").each(function () { 
    if(state == 1) {
      if($(this).find("a.unchecked, a.undetermined").size() - 1 > 0) {
        $(this).parents("li").andSelf().children("a").removeClass("unchecked").removeClass("checked").addClass("undetermined");
        return false;
      }
      else $(this).children("a").removeClass("unchecked").removeClass("undetermined").addClass("checked");
    }
    else {
      if($(this).find("a.checked, a.undetermined").size() - 1 > 0) {
        $(this).parents("li").andSelf().children("a").removeClass("unchecked").removeClass("checked").addClass("undetermined");
        return false;
      }
      else $(this).children("a").removeClass("checked").removeClass("undetermined").addClass("unchecked");
    }
  });
}