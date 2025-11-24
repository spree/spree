// Rails stuff
import "@rails/actioncable"
import "@rails/actiontext"
import "@hotwired/turbo-rails"
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()

import "trix"

import "chartkick"
import "Chart.bundle"

import LocalTime from "local-time"
import "mapkick/bundle"

// Helpers
import 'spree/admin/helpers/tinymce'
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
import CheckboxSelectAll from 'stimulus-checkbox-select-all'
import Dialog from "@stimulus-components/dialog"
import TextareaAutogrow from 'stimulus-textarea-autogrow'
import Notification from 'stimulus-notification'
import PasswordVisibility from 'stimulus-password-visibility'
import RailsNestedForm from '@stimulus-components/rails-nested-form'
import Reveal from 'stimulus-reveal-controller'
import Sortable from 'stimulus-sortable'
import ActiveStorageUpload from 'spree/admin/controllers/active_storage_upload_controller'
import AdminController from 'spree/admin/controllers/admin_controller'
import AssetUploaderController from 'spree/admin/controllers/asset_uploader_controller'
import AutocompleteSelectController from 'spree/admin/controllers/autocomplete_select_controller'
import AutoScrollController from 'spree/admin/controllers/auto_scroll_controller'
import BetterSliderController from 'spree/admin/controllers/better_slider_controller'
import BlockFormController from 'spree/admin/controllers/block_form_controller'
import BulkOperationController from 'spree/admin/controllers/bulk_operation_controller'
import CalculatorFieldsController from 'spree/admin/controllers/calculator_fields_controller'
import CalendarRangeController from 'spree/admin/controllers/calendar_range_controller'
import Clipboard from 'spree/admin/controllers/clipboard_controller'
import CodeMirrorController from 'spree/admin/controllers/codemirror_controller'
import ColorPaletteController from 'spree/admin/controllers/color_palette_controller'
import ColorPickerController from 'spree/admin/controllers/color_picker_controller'
import DropdownController from 'spree/admin/controllers/dropdown_controller'
import FiltersController from 'spree/admin/controllers/filters_controller'
import FontPickerController from 'spree/admin/controllers/font_picker_controller'
import HighlightController from 'spree/admin/controllers/highlight_controller'
import ImportFormController from 'spree/admin/controllers/import_form_controller'
import MediaFormController from 'spree/admin/controllers/media_form_controller'
import MultiInputController from 'spree/admin/controllers/multi_input_controller'
import MultiTomSelectController from 'spree/admin/controllers/multi_tom_select_controller'
import OrderBillingAddressController from 'spree/admin/controllers/order_billing_address_controller'
import PageBuilderController from 'spree/admin/controllers/page_builder_controller'
import PasswordToggle from 'spree/admin/controllers/password_toggle_controller'
import ProductFormController from 'spree/admin/controllers/product_form_controller'
import RangeInputController from 'spree/admin/controllers/range_input_controller'
import ReturnItemsController from 'spree/admin/controllers/return_items_controller'
import ReplaceController from 'spree/admin/controllers/replace_controller'
import RowLinkController from 'spree/admin/controllers/row_link_controller'
import RuleFormController from 'spree/admin/controllers/rule_form_controller'
import SearchPickerController from 'spree/admin/controllers/search_picker_controller'
import SectionFormController from 'spree/admin/controllers/section_form_controller'
import SelectController from 'spree/admin/controllers/select_controller'
import SeoFormController from 'spree/admin/controllers/seo_form_controller'
import SidebarController from 'spree/admin/controllers/sidebar_controller'
import SlugFormController from 'spree/admin/controllers/slug_form_controller'
import StickyController from 'spree/admin/controllers/sticky_controller'
import SortableAutoSubmit from 'spree/admin/controllers/sortable_auto_submit_controller'
import SortableTree from 'spree/admin/controllers/sortable_tree_controller'
import StockTransferController from 'spree/admin/controllers/stock_transfer_controller'
import StoreFormController from 'spree/admin/controllers/store_form_controller'
import TabsController from 'spree/admin/controllers/tabs_controller'
import TooltipController from 'spree/admin/controllers/tooltip_controller'
import TurboSubmitButtonController from 'spree/admin/controllers/turbo_submit_button_controller'
import UnitSystemController from 'spree/admin/controllers/unit_system_controller'
import VariantsFormController from 'spree/admin/controllers/variants_form_controller'
import AddressAutocompleteController from 'spree/core/controllers/address_autocomplete_controller'
import AddressFormController from 'spree/core/controllers/address_form_controller'
import DisableSubmitButtonController from 'spree/core/controllers/disable_submit_button_controller'
import EnableButtonController from 'spree/core/controllers/enable_button_controller'

application.register('active-storage-upload', ActiveStorageUpload)
application.register('address-autocomplete', AddressAutocompleteController)
application.register('address-form', AddressFormController)
application.register('admin', AdminController)
application.register('asset-uploader', AssetUploaderController)
application.register('auto-scroll', AutoScrollController)
application.register('auto-submit', AutoSubmit)
application.register('autocomplete-select', AutocompleteSelectController)
application.register('better-slider', BetterSliderController)
application.register('block-form', BlockFormController)
application.register('bulk-dialog', Dialog)
application.register('bulk-operation', BulkOperationController)
application.register('calculator-fields', CalculatorFieldsController)
application.register('calendar-range', CalendarRangeController)
application.register('checkbox-select-all', CheckboxSelectAll)
application.register('clipboard', Clipboard)
application.register('codemirror', CodeMirrorController)
application.register('color-palette', ColorPaletteController)
application.register('color-picker', ColorPickerController)
application.register('dialog', Dialog)
application.register('drawer', Dialog)
application.register('disable-submit-button', DisableSubmitButtonController)
application.register('dropdown', DropdownController)
application.register('enable-button', EnableButtonController)
application.register('export-dialog', Dialog)
application.register('filters', FiltersController)
application.register('font-picker', FontPickerController)
application.register('highlight', HighlightController)
application.register('import-form', ImportFormController)
application.register('media-form', MediaFormController)
application.register('multi-input', MultiInputController)
application.register('multi-tom-select', MultiTomSelectController)
application.register('nested-form', RailsNestedForm)
application.register('notification', Notification)
application.register('order-billing-address', OrderBillingAddressController)
application.register('page-builder', PageBuilderController)
application.register('password-toggle', PasswordToggle)
application.register('password-visibility', PasswordVisibility)
application.register('product-form', ProductFormController)
application.register('range-input', RangeInputController)
application.register('replace', ReplaceController)
application.register('return-items', ReturnItemsController)
application.register('reveal', Reveal)
application.register('row-link', RowLinkController)
application.register('rule-form', RuleFormController)
application.register('search-picker', SearchPickerController)
application.register('section-form', SectionFormController)
application.register('select', SelectController)
application.register('seo-form', SeoFormController)
application.register('sidebar', SidebarController)
application.register('slug-form', SlugFormController)
application.register('sticky', StickyController)
application.register('sortable', Sortable)
application.register('sortable-auto-submit', SortableAutoSubmit)
application.register('sortable-tree', SortableTree)
application.register('stock-transfer', StockTransferController)
application.register('store-form', StoreFormController)
application.register('tabs', TabsController)
application.register('tooltip', TooltipController)
application.register('turbo-submit-button', TurboSubmitButtonController)
application.register('textarea-autogrow', TextareaAutogrow)
application.register('unit-system', UnitSystemController)
application.register('variants-form', VariantsFormController)

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
