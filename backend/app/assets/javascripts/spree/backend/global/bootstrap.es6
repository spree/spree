// Use this file for Boostrap customization applied across the Spree Backend

document.addEventListener('DOMContentLoaded', function() {
  $('.with-tip').each(function() {
    $(this).tooltip({
      container: $(this)
    })
  })

  $('.with-tip').on('show.bs.tooltip', function(event) {
    if (('ontouchstart' in window)) {
      event.preventDefault()
    }
  })
})
