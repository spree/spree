/* eslint-disable no-undef */
/* global variantLineItemTemplate */

document.addEventListener('DOMContentLoaded', function() {
  $('#add_line_item_variant_id').change(handleVariantSelection)

  //
  // Handle edit click
  const editLineItemButtons = document.querySelectorAll('a.edit-line-item')
  if (editLineItemButtons == null) return

  editLineItemButtons.forEach(function(el) {
    el.addEventListener('click', function(event) {
      event.preventDefault()

      toggleLineItemEdit(el)
    })
  })

  //
  // Handle cancel click
  const cancelLineItemButtons = document.querySelectorAll('a.cancel-line-item')
  if (cancelLineItemButtons == null) return

  cancelLineItemButtons.forEach(function(el) {
    el.addEventListener('click', function(event) {
      event.preventDefault()

      toggleLineItemEdit(el)
    })
  })

  //
  // Handle save click
  const saveLineItemButtons = document.querySelectorAll('a.save-line-item')
  if (saveLineItemButtons == null) return

  saveLineItemButtons.forEach(function(el) {
    el.addEventListener('click', function(event) {
      event.preventDefault()

      const qty = el.closest('tr').querySelector('input.line_item_quantity').value
      const lineItemId = parseInt(el.dataset.lineItemId, 10)
      const quantity = parseInt(qty, 10)

      adjustLineItemQuantity(lineItemId, quantity)
    })
  })

  //
  // Handle delete click
  const deleteLineItemButtons = document.querySelectorAll('a.delete-line-item')
  if (deleteLineItemButtons == null) return

  deleteLineItemButtons.forEach(function(el) {
    el.addEventListener('click', function(event) {
      event.preventDefault()

      if (confirm(Spree.translations.are_you_sure_delete)) {
        const lineItemId = parseInt(el.dataset.lineItemId, 10)
        deleteLineItem(lineItemId)
      }
    })
  })
})

//
// Add line Item to order
const addVariant = function () {
  const variantId = document.querySelector('select.variant_autocomplete').value
  const quantity = document.querySelector('input#variant_quantity').value

  addLineItem(variantId, quantity)
}

//
// Toggle line item edit
const toggleLineItemEdit = function (el) {
  const parent = el.closest('tr')

  parent.querySelector('a.edit-line-item').classList.toggle('is-hidden')
  parent.querySelector('a.cancel-line-item').classList.toggle('is-hidden')
  parent.querySelector('a.save-line-item').classList.toggle('is-hidden')
  parent.querySelector('a.delete-line-item').classList.toggle('is-hidden')
  parent.querySelector('td.line-item-qty-show').classList.toggle('is-hidden')
  parent.querySelector('td.line-item-qty-edit').classList.toggle('is-hidden')
}

//
// Adds selected variant to page.
const handleVariantSelection = function () {
  const variantId = this.value

  const variant = _.find(window.variants, function (variant) {
    return variant.id === variantId
  })

  const stockDetails = document.querySelector('#stock_details')
  stockDetails.innerHTML = variantLineItemTemplate({ variant: variant.attributes })

  const addVariantButton = document.querySelector('button.add_variant')
  addVariantButton.addEventListener('click', addVariant)
}
