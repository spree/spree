$(document).ready(function() {
  if ($(".categories input:checked").length > 0) {
    $('input[type=checkbox]:not(:checked)').attr('disabled', true);
  }

  $('.categories input[type=checkbox]').change(function(){
    if($(this).is(':checked')) {
      $('input[type=checkbox]').attr('disabled', true);
      $(this).removeAttr('disabled');
    } else {
      $('input[type=checkbox]').removeAttr('disabled');
    }
  });
});
