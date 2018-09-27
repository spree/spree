$(document).ready(function () {
  if ($('#permalink_part_display').length) {
    var field = $('#permalink_part')
    var target = $('#permalink_part_display')
    var permalinkPartDefault = target.text().trim()
    target.text(permalinkPartDefault + field.val())
    field.on('keyup blur', function () {
      target.text(permalinkPartDefault + $(this).val())
    })
  };
})
