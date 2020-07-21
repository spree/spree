document.addEventListener('DOMContentLoaded', function() {
  // Custom Select2

  // Fix for Select2 v3.x using overlay mask to close any opened Select2 instances
  // The overlay mask stops you lowering the z-index of the opend Select2 instance
  // This is not needed if upgraded to Select2 v4.x
  window.addEventListener('click', function(e) {
    var select2Drop = document.getElementById('select2-drop')

    if (select2Drop) {
      if (select2Drop.contains(e.target)) {
        // Click in the Select2 dropdown and do nothing...
      } else {
        $('*').select2('close')
      }
    }
  })

  // Inititate Select2 on any select element with the class .select2
  $('select.select2').select2({
    allowClear: true
  })
})
