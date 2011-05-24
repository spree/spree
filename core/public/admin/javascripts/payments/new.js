$(document).ready(function(){
  
  $("#card_new").radioControlsVisibilityOfElement('#card_form');
  
  $('select.jump_menu').change(function(){
    window.location = this.options[this.selectedIndex].value;
  });

});