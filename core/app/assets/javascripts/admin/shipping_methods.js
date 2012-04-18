$(document).ready(function() {
  if ($(".categories input:checked").length > 0) {
    $('input[type=checkbox]:not(:checked)').attr('disabled', true);
  }

  categoryCheckboxes = '.categories input[type=checkbox]';
  $(categoryCheckboxes).change(function(){
    if($(this).is(':checked')) {
      $(categoryCheckboxes + ':not(:checked)').attr('disabled', true);
      $(this).removeAttr('disabled');
    } else {
      $('input[type=checkbox]').removeAttr('disabled');
    }
  });
});
