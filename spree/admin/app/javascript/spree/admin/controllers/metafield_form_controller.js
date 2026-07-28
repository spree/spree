import { Controller } from '@hotwired/stimulus'

// Mirrors Spree::MetafieldDefinition searchable/sortable type capabilities.
const SEARCHABLE_TYPES = new Set([
  'Spree::Metafields::ShortText',
  'Spree::Metafields::LongText',
  'Spree::Metafields::Number',
])

const SORTABLE_TYPES = new Set([
  'Spree::Metafields::ShortText',
  'Spree::Metafields::Number',
])

export default class extends Controller {
  static targets = ['metafieldType', 'searchable', 'sortable']

  connect() {
    this.restoreCheckbox(this.searchableTarget)
    this.restoreCheckbox(this.sortableTarget)
    this.syncCapabilities()
  }

  typeChanged(event) {
    if (this.hasMetafieldTypeTarget && event?.target && event.target !== this.metafieldTypeTarget) {
      return
    }

    this.syncCapabilities()
    this.clearCapabilityErrors(this.searchableTarget)
    this.clearCapabilityErrors(this.sortableTarget)
    this.clearAlertErrors(['searchable', 'sortable'])
  }

  syncCapabilities() {
    if (!this.hasMetafieldTypeTarget) return

    const type = this.metafieldTypeTarget.value
    this.applyCapability(this.searchableTarget, SEARCHABLE_TYPES.has(type))
    this.applyCapability(this.sortableTarget, SORTABLE_TYPES.has(type))
  }

  applyCapability(input, supported) {
    if (!input) return

    input.disabled = !supported
    if (!supported) input.checked = false
  }

  // Unwrap .field_with_errors so input~label sibling styles work again.
  // Leaves .formError text in place until Type changes.
  restoreCheckbox(input) {
    if (!input) return

    const checkbox = input.closest('.form-checkbox')
    checkbox?.querySelectorAll(':scope > .field_with_errors').forEach((wrapper) => {
      wrapper.replaceWith(...wrapper.childNodes)
    })
  }

  clearCapabilityErrors(input) {
    if (!input) return

    this.restoreCheckbox(input)
    input.closest('.form-group')?.querySelector('.formError')?.remove()
  }

  clearAlertErrors(fields) {
    const form = this.element.closest('form') || this.element
    const alert = form.querySelector('.alert-danger')
    if (!alert) return

    alert.querySelectorAll('li').forEach((li) => {
      const text = li.textContent.toLowerCase()
      if (fields.some((name) => text.includes(name))) li.remove()
    })
    if (!alert.querySelector('li')) alert.remove()
  }
}
