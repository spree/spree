$(document).ready(function(){

  $("#card_new").radioControlsVisibilityOfElement('#card_form');

  $('select.jump_menu').change(function(){
    window.location = this.options[this.selectedIndex].value;
  });

  $('#cvv_link').click(function(event){
    window_name = 'cvv_info';
    window_options = 'left=20,top=20,width=500,height=500,toolbar=0,resizable=0,scrollbars=1';
    window.open($(this).attr('href'), window_name, window_options);
    event.preventDefault();
  });

});