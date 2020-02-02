window.lazySizesConfig = window.lazySizesConfig || {}
window.lazySizesConfig.loadMode = 1
window.lazySizesConfig.init = false
window.lazySizesConfig.loadHidden = false

Spree.ready(function ($) {
  window.lazySizes.init()
})
