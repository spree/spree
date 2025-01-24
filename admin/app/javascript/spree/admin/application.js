// Rails stuff
import "@rails/actioncable"
import "@rails/actiontext"
import "@hotwired/turbo-rails"
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()

import "chartkick"
import "Chart.bundle"

import LocalTime from "local-time"
import "mapkick/bundle"

// Helpers
import 'spree/admin/helpers/tinymce'
import 'spree/admin/helpers/navs'
import 'spree/admin/helpers/canvas'
import 'spree/admin/helpers/trix/video_embed'
import 'spree/admin/helpers/bootstrap'

// Stimulus controllers
import { Application } from "@hotwired/stimulus"

let application
if (typeof Stimulus === 'undefined') {
  application = Application.start()

  // Configure Stimulus development experience
  application.debug = false
  window.Stimulus = application
} else {
  application = window.Stimulus
}
import AutoSubmit from '@stimulus-components/auto-submit'
import TextareaAutogrow from 'stimulus-textarea-autogrow'
import Notification from 'stimulus-notification'
import PasswordVisibility from 'stimulus-password-visibility'
import RailsNestedForm from '@stimulus-components/rails-nested-form'
import Reveal from 'stimulus-reveal-controller'
import Sortable from 'stimulus-sortable'
import { Tabs } from 'tailwindcss-stimulus-components'

import AccountBillingAddressController from 'spree/admin/controllers/account_billing_address_controller'
import ActiveStorageUpload from 'spree/admin/controllers/active_storage_upload_controller'
// // import AddressAutocompleteController from 'spree/addre/controllersss_autocomplete_controller'
// // import AddressFormController from 'spree/addre/controllersss_form_controller'
import AssetUploaderController from 'spree/admin/controllers/asset_uploader_controller'
import AutocompleteSelectController from 'spree/admin/controllers/autocomplete_select_controller'
import BetterSliderController from 'spree/admin/controllers/better_slider_controller'
import BlockFormController from 'spree/admin/controllers/block_form_controller'
import BootstrapTabs from 'spree/admin/controllers/bootstrap_tabs_controller'
import BulkOperationController from 'spree/admin/controllers/bulk_operation_controller'
import CalculatorFieldsController from 'spree/admin/controllers/calculator_fields_controller'
import CalendarRangeController from 'spree/admin/controllers/calendar_range_controller'
import Clipboard from 'spree/admin/controllers/clipboard_controller'
import ColorPaletteController from 'spree/admin/controllers/color_palette_controller'
import ColorPickerController from 'spree/admin/controllers/color_picker_controller'
// // import EnableButtonController from 'spree/enabl/controllerse_button_controller'
// import FlatfileUploaderController from 'spree/admin/controllers/flatfile_uploader_controller'
// import FiltersController from 'spree/admin/controllers/filters_controller'
// import FontPickerController from 'spree/admin/controllers/font_picker_controller'
// import MediaFormController from 'spree/admin/controllers/media_form_controller'
// import MultiInputController from 'spree/admin/controllers/multi_input_controller'
// import OrderBillingAddressController from 'spree/admin/controllers/order_billing_address_controller'
// import PageBuilderController from 'spree/admin/controllers/page_builder_controller'
// import PasswordToggle from 'spree/admin/controllers/password_toggle_controller'
// import ProductFormController from 'spree/admin/controllers/product_form_controller'
// import RangeInputController from 'spree/admin/controllers/range_input_controller'
// import ReplaceController from 'spree/admin/controllers/replace_controller'
// import RowLinkController from 'spree/admin/controllers/row_link_controller'
// import RuleFormController from 'spree/admin/controllers/rule_form_controller'
// import SearchPickerController from 'spree/admin/controllers/search_picker_controller'
// import SectionFormController from 'spree/admin/controllers/section_form_controller'
// import SelectController from 'spree/admin/controllers/select_controller'
// import SeoFormController from 'spree/admin/controllers/seo_form_controller'
// import SlugFormController from 'spree/admin/controllers/slug_form_controller'
// import SortableTree from 'spree/admin/controllers/sortable_tree_controller'
// import StockTransferController from 'spree/admin/controllers/stock_transfer_controller'
// import StoreFormController from 'spree/admin/controllers/store_form_controller'
// import UnitSystemController from 'spree/admin/controllers/unit_system_controller'
// import VariantsFormController from 'spree/admin/controllers/variants_form_controller'
// import WebhooksSubscriberEventsController from 'spree/admin/controllers/webhook_subscriber_events_controller'

application.register('account-billing-address', AccountBillingAddressController)
application.register('active-storage-upload', ActiveStorageUpload)
// // application.register('address-autocomplete', AddressAutocompleteController)
// // application.register('address-form', AddressFormController)
application.register('asset-uploader', AssetUploaderController)
application.register('auto-submit', AutoSubmit)
application.register('autocomplete-select', AutocompleteSelectController)
application.register('better-slider', BetterSliderController)
application.register('block-form', BlockFormController)
application.register('bootstrap-tabs', BootstrapTabs) // We should merge with tabs controller/remove this
application.register('bulk-operation', BulkOperationController)
application.register('calculator-fields', CalculatorFieldsController)
application.register('calendar-range', CalendarRangeController)
application.register('clipboard', Clipboard)
application.register('color-palette', ColorPaletteController)
application.register('color-picker', ColorPickerController)
// // application.register('enable-button', EnableButtonController)
// application.register('flatfile-uploader', FlatfileUploaderController)
// application.register('filters', FiltersController)
// application.register('font-picker', FontPickerController)
// application.register('media-form', MediaFormController)
// application.register('multi-input', MultiInputController)
application.register('nested-form', RailsNestedForm)
application.register('notification', Notification)
// application.register('order-billing-address', OrderBillingAddressController)
// application.register('page-builder', PageBuilderController)
// application.register('password-toggle', PasswordToggle)
application.register('password-visibility', PasswordVisibility)
// application.register('product-form', ProductFormController)
// application.register('range-input', RangeInputController)
// application.register('replace', ReplaceController)
application.register('reveal', Reveal)
// application.register('row-link', RowLinkController)
// application.register('rule-form', RuleFormController)
// application.register('search-picker', SearchPickerController)
// application.register('section-form', SectionFormController)
// application.register('select', SelectController)
// application.register('seo-form', SeoFormController)
// application.register('slug-form', SlugFormController)
application.register('sortable', Sortable)
// application.register('sortable-tree', SortableTree)
// application.register('stock-transfer', StockTransferController)
// application.register('store-form', StoreFormController)
application.register('tabs', Tabs)
application.register('textarea-autogrow', TextareaAutogrow)
// application.register('unit-system', UnitSystemController)
// application.register('variants-form', VariantsFormController)
// application.register('webhooks-subscriber-events', WebhooksSubscriberEventsController)

LocalTime.start()

Trix.config.blockAttributes.heading1.tagName = 'h2'

document.addEventListener('turbo:before-visit', _event => {
  const content = document.getElementById('content')
  if (content) content.classList.add('blurred')
})

document.addEventListener('turbo:load', _event => {
  const content = document.getElementById('content')
  if (content) content.classList.remove('blurred')
})

document.addEventListener('turbo:submit-start', () => {
  Turbo.navigator.delegate.adapter.progressBar.setValue(0)
  Turbo.navigator.delegate.adapter.progressBar.show()
})
document.addEventListener('turbo:submit-end', () => {
  Turbo.navigator.delegate.adapter.progressBar.setValue(1)
  Turbo.navigator.delegate.adapter.progressBar.hide()
})
