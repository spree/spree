import 'jquery'
import 'bootstrap'
import { lockScroll, unlockScroll } from 'spree/core/helpers/scroll_lock'


const initTooltips = () => {
  $('.with-tip').each(function() {
    $(this).tooltip()
  })

  $('.with-tip').on('show.bs.tooltip', function(event) {
    if (('ontouchstart' in window)) {
      event.preventDefault()
    }
  })
}

const removeTooltips = () => {
  $('.with-tip').each(function() {
    $(this).tooltip('dispose')
  })
}

$('.modal').on('show.bs.modal', lockScroll)
$('.modal').on('hide.bs.modal', unlockScroll)

document.addEventListener("turbo:click", removeTooltips)
document.addEventListener("turbo:load", initTooltips)
document.addEventListener('turbo:frame-render', initTooltips)
