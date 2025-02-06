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

import AccordionController from 'spree/storefront/controllers/accordion_controller'
import AccountNavController from 'spree/storefront/controllers/account_nav_controller'
import AddressFormController from 'spree/core/controllers/address_form_controller'
import AutoSubmit from '@stimulus-components/auto-submit'
import CartController from 'spree/storefront/controllers/cart_controller'
import CheckoutStripeButtonController from 'spree/storefront/controllers/stripe_button_controller'
import ClearInputController from 'spree/storefront/controllers/clear_input_controller'
import CopyInputController from 'spree/storefront/controllers/copy_input_controller'
import DeliveryDatesController from 'spree/storefront/controllers/delivery_dates_controller'
import DropdownController from 'spree/storefront/controllers/dropdown_controller'
import EnableButtonController from 'spree/core/controllers/enable_button_controller'
import HeaderController from 'spree/storefront/controllers/header_controller'
import InfiniteScrollController from 'spree/storefront/controllers/infinite_scroll_controller'
import LightboxController from 'spree/storefront/controllers/lightbox_controller'
import MobileNavController from 'spree/storefront/controllers/mobile_nav_controller'
import NoUiSliderController from 'spree/storefront/controllers/no_ui_slider_controller'
import PDPDesktopGallery from 'spree/storefront/controllers/pdp_desktop_gallery'
import PlpVariantPickerController from 'spree/storefront/controllers/plp_variant_picker_controller'
import ProductFormController from 'spree/storefront/controllers/product_form_controller'
import QuantityPickerController from 'spree/storefront/controllers/quantity_picker_controller'
import SearchableListController from 'spree/storefront/controllers/searchable_list_controller'
import SearchSuggestionsController from 'spree/storefront/controllers/search_suggestions_controller'
import SlideoverController from 'spree/storefront/controllers/slideover_controller'
import StickyButtonController from 'spree/storefront/controllers/sticky_button_controller'
import StripePaymentMethodMessagingElementController from 'spree/storefront/controllers/stripe_payment_method_messaging_element_controller'
import SwiperController from 'spree/storefront/controllers/swiper_controller'
import ToggleMenuController from 'spree/storefront/controllers/toggle_menu_controller'
import TurboStreamFormController from 'spree/storefront/controllers/turbo_stream_form_controller'
import WishedItemController from 'spree/storefront/controllers/wished_item_controller'

application.register('accordion', AccordionController)
application.register('account-nav', AccountNavController)
application.register('address-form', AddressFormController)
application.register('auto-submit', AutoSubmit)
application.register('cart', CartController)
application.register('checkout-stripe-button', CheckoutStripeButtonController)
application.register('clear-input', ClearInputController)
application.register('copy-input', CopyInputController)
application.register('delivery-dates', DeliveryDatesController)
application.register('dropdown', DropdownController)
application.register('enable-button', EnableButtonController)
application.register('header', HeaderController)
application.register('infinite-scroll', InfiniteScrollController)
application.register('lightbox', LightboxController)
application.register('mobile-nav', MobileNavController)
application.register('no-ui-slider', NoUiSliderController)
application.register('pdp-desktop-gallery', PDPDesktopGallery)
application.register('plp-variant-picker', PlpVariantPickerController)
application.register('product-form', ProductFormController)
application.register('quantity-picker', QuantityPickerController)
application.register('search-suggestions', SearchSuggestionsController)
application.register('searchable-list', SearchableListController)
application.register('slideover', SlideoverController)
application.register('slideover-account', SlideoverController)
application.register('sticky-button', StickyButtonController)
application.register('stripe-payment-method-messaging-element', StripePaymentMethodMessagingElementController)
application.register('carousel', SwiperController)
application.register('toggle-menu', ToggleMenuController)
application.register('turbo-stream-form', TurboStreamFormController)
application.register('wished-item', WishedItemController)

// Import and register all TailwindCSS Components
import { Alert, Toggle, Modal } from 'tailwindcss-stimulus-components'
application.register('alert', Alert)
application.register('toggle', Toggle)
application.register('modal', Modal)

import Reveal from 'stimulus-reveal-controller'
application.register('reveal', Reveal)

import ScrollTo from 'stimulus-scroll-to'
application.register('scroll-to', ScrollTo)

import ReadMore from 'stimulus-read-more'
application.register('read-more', ReadMore)


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


console.log("Loaded storefront application.js")
