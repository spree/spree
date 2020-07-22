document.addEventListener('DOMContentLoaded', function() {
  // Inititate Select2 on any select element with the class .select2
  $('select.select2').select2({
    allowClear: true
  })

  // BELOW: z-index fix for Select2 v3.x to lower the z-index of an opened Select2.
  // The javascript below is not needed if Spree is updated to use Select2 v4.x
  window.addEventListener('click', function(e) {
    var select2Drop = document.getElementById('select2-drop')

    if (select2Drop) {
      if (select2Drop.contains(e.target)) {
        // Clicking inside the Select2 dropdown does nothing...
      } else {
        // Clicking outside the Select2 dropdown close all open Select2 dropdowns.
        $('*').select2('close')
      }
    }
  })
})
