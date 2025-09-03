import '@hotwired/turbo-rails'
import { Application } from '@hotwired/stimulus'

let application

if (typeof window.Stimulus === "undefined") {
  application = Application.start()
  application.debug = false
  window.Stimulus = application
} else {
  application = window.Stimulus
}

import { Alert, Toggle } from 'tailwindcss-stimulus-components'
application.register('alert', Alert)
application.register('toggle', Toggle)


// We need to preload the carousel controller, otherwise it causes a huge layout shift when it's loaded.
import CarouselController from 'spree/storefront/controllers/carousel_controller'
application.register('carousel', CarouselController)

// We need to make allow list of controllers to be loaded, this is needed because by default Stimulus will try to load all the controllers that it encounters in the DOM.
// Since Spree Storefront can be extended with custom views/partials, we need to be able to control which controllers can be loaded from our application.

const controllers = [
  'accordion',
  'account-nav',
  'address-autocomplete',
  'address-form',
  'auto-submit',
  'card-validation',
  'cart',
  'checkout-address-book',
  'checkout-delivery',
  'checkout-promotions',
  'checkout-summary',
  'clear-input',
  'copy-input',
  'dropdown',
  'enable-button',
  'header',
  'infinite-scroll',
  'lightbox',
  'mobile-nav',
  'modal',
  'no-ui-slider',
  'pdp-desktop-gallery',
  'plp-variant-picker',
  'product-form',
  'quantity-picker',
  'read-more',
  'reveal',
  'scroll-to',
  'search-suggestions',
  'searchable-list',
  'slideover-account',
  'slideover',
  'sticky-button',
  'textarea-autogrow',
  'toggle-menu',
  'turbo-stream-form',
  'wished-item',
]


// Manifest is needed to load controllers that names don't match the controller filename, or are not in the controllers directory.
const manifest = {
  "auto-submit": "@stimulus-components/auto-submit",
  "address-form": "spree/core/controllers/address_form_controller",
  "address-autocomplete": "spree/core/controllers/address_autocomplete_controller",
  "enable-button": "spree/core/controllers/enable_button_controller",
  "slideover-account": "spree/storefront/controllers/slideover_controller",
  "reveal": "stimulus-reveal-controller",
  "scroll-to": "stimulus-scroll-to",
  "read-more": "stimulus-read-more",
  "textarea-autogrow": "stimulus-textarea-autogrow"
}

import { lazyLoadControllersFromManifest } from "spree/storefront/helpers/lazy_load_controllers_with_manifest"

lazyLoadControllersFromManifest(controllers, "spree/storefront/controllers", application, manifest)


const scrollToOverlay = (overlay) => {
  const { top, left } = overlay.getBoundingClientRect()

  window.scroll({
    behavior: 'smooth',
    top: window.scrollY + top - window.innerHeight / 2 + overlay.offsetHeight / 2,
    left: left + window.scrollX
  })
}

// page builder UI
const toggleHighlightEditorOverlay = (query) => {
  const overlay = document.querySelector(query)

  if (overlay) {
    if (overlay.classList.contains('editor-overlay-hover')) {
      overlay.classList.remove('editor-overlay-hover')
    } else {
      overlay.classList.add('editor-overlay-hover')

      scrollToOverlay(overlay)
    }
  }
}


const makeOverlayActive = (id) => {
  const overlay = document.querySelector(`.editor-overlay[data-editor-id="${id}"]`)

  document.querySelectorAll('.editor-overlay-active').forEach((el) => {
    el.classList.remove('editor-overlay-active')
  })

  if (overlay) {
    overlay.classList.add('editor-overlay-active')
    scrollToOverlay(overlay)
  }
}

const toggleHighlightElement = (id) => {
  toggleHighlightEditorOverlay(`.editor-overlay[data-editor-id="${id}"]`)
}

window.scrollToOverlay = scrollToOverlay
window.toggleHighlightElement = toggleHighlightElement
window.makeOverlayActive = makeOverlayActive

document.addEventListener('turbo:submit-start', () => {
  Turbo.navigator.delegate.adapter.progressBar.setValue(0)
  Turbo.navigator.delegate.adapter.progressBar.show()
})

document.addEventListener('turbo:submit-end', () => {
  Turbo.navigator.delegate.adapter.progressBar.setValue(100)
  Turbo.navigator.delegate.adapter.progressBar.hide()
})

function replaceCsrfMetaTags() {
  const csrfMetaTagsTemplate = document.querySelector('template#csrf_meta_tags')
  if (!csrfMetaTagsTemplate) return

  const csrfMetaTags = csrfMetaTagsTemplate.content.cloneNode(true)

  document.head.querySelectorAll('meta[name="csrf-token"]').forEach((tag) => tag.remove())
  document.head.querySelectorAll('meta[name="csrf-param"]').forEach((tag) => tag.remove())

  document.head.appendChild(csrfMetaTags)
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', replaceCsrfMetaTags)
} else {
  replaceCsrfMetaTags()
}
