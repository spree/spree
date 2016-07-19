$(document).ready(function() {
  if ($('#permalink_part_display').length) {
    var field  = $('#permalink_part'),
        target = $('#permalink_part_display'),
        permalink_part_default = target.text().trim();

    target.text(permalink_part_default + field.val());
    field.on('keyup blur', function () {
      target.text(permalink_part_default + $(this).val());
    });
  };
});
