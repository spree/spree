/* eslint-disable no-unused-vars */
/* eslint-disable no-undef */

//
// Toggle Tracking Edit
const toggleTrackingEdit = function(event) {
  event.preventDefault()

  const editTrackig = this.closest('tbody').querySelector('tr.edit-tracking')
  const showTrackig = this.closest('tbody').querySelector('tr.show-tracking')

  editTrackig.classList.toggle('is-hidden')
  showTrackig.classList.toggle('is-hidden')
}

//
// Toggle Shipping Method Edit
const toggleMethodEdit = function(event) {
  event.preventDefault()

  const editMethod = this.closest('tbody').querySelector('tr.edit-method')
  const showMethod = this.closest('tbody').querySelector('tr.show-method')

  editMethod.classList.toggle('is-hidden')
  showMethod.classList.toggle('is-hidden')
}

//
// Toggle Line Item Edit
const toggleItemEdit = function(event) {
  event.preventDefault()

  const linkParent = this.closest('span')
  const editItem = this.closest('tr').querySelector('td.item-qty-edit')
  const showItem = this.closest('tr').querySelector('td.item-qty-show')
  const editItemButton = linkParent.querySelector('a.edit-item')
  const cancelItemButton = linkParent.querySelector('a.cancel-item')
  const splitItemButton = linkParent.querySelector('a.split-item')
  const saveItemButton = linkParent.querySelector('a.save-item')
  const deleteItemButton = linkParent.querySelector('a.delete-item')

  editItem.classList.toggle('is-hidden')
  showItem.classList.toggle('is-hidden')
  editItemButton.classList.toggle('is-hidden')
  cancelItemButton.classList.toggle('is-hidden')
  splitItemButton.classList.toggle('is-hidden')
  saveItemButton.classList.toggle('is-hidden')
  deleteItemButton.classList.toggle('is-hidden')
}

//
// Start Line Item Split
const sartLineItemSplit = function(event) {
  event.preventDefault()

  const linkParent = this.closest('span')
  const allCancleSplitButtons = document.querySelectorAll('a.cancel-split')

  allCancleSplitButtons.forEach(function (el) {
    el.click()
  })

  const editItem = linkParent.querySelector('a.edit-item')
  const splitItem = linkParent.querySelector('a.split-item')
  const deleteItem = linkParent.querySelector('a.delete-item')

  editItem.classList.toggle('is-hidden')
  splitItem.classList.toggle('is-hidden')
  deleteItem.classList.toggle('is-hidden')

  const variantId = this.dataset.variantId

  startItemSplit(this, variantId, formatReturnedDataFromStartLineItemSpit)
}
const formatReturnedDataFromStartLineItemSpit = function(data, clickedLink) {
  formatDataForVariants(data.included)
  const variant = data.included[0]

  const maxQuantity = clickedLink.closest('tr').dataset.itemQuantity
  const variantSplitTemplate = document.querySelector('#variant_split_template').innerHTML
  const splitItemTemplate = Handlebars.compile(variantSplitTemplate)
  const tableRow = clickedLink.closest('tr')

  tableRow.insertAdjacentHTML('afterend', splitItemTemplate({ variant: variant, shipments: shipments, max_quantity: maxQuantity }))

  const cancelThisSplitButton = document.querySelector('a.cancel-split')
  const saveThisSplitButton = document.querySelector('a.save-split')

  cancelThisSplitButton.addEventListener('click', cancelItemSplit)
  saveThisSplitButton.addEventListener('click', completeItemSplit)

  // TODO: REMOVE JQUERY
  $('#item_stock_location').select2({ width: 'resolve', placeholder: Spree.translations.item_stock_placeholder })
}

//
// Cancel Line Item Split
const cancelItemSplit = function(event) {
  event.preventDefault()

  const prevRow = this.closest('tr').previousElementSibling
  this.closest('tr').remove()

  const splitEditButton = prevRow.querySelector('a.edit-item')
  const splitButton = prevRow.querySelector('a.split-item')
  const splitDeleteButton = prevRow.querySelector('a.delete-item')

  splitEditButton.classList.toggle('is-hidden')
  splitButton.classList.toggle('is-hidden')
  splitDeleteButton.classList.toggle('is-hidden')
}

document.addEventListener('DOMContentLoaded', function() {
  //
  // Handle Split Click
  const splitItemButtons = document.querySelectorAll('a.split-item')
  splitItemButtons.forEach(function(el) {
    el.addEventListener('click', sartLineItemSplit)
  })

  //
  // Handle Edit Click
  const editItemButtons = document.querySelectorAll('a.edit-item')
  editItemButtons.forEach(function(el) {
    el.addEventListener('click', toggleItemEdit)
  })

  //
  // Handle Cancel Click
  const cancleItemButtons = document.querySelectorAll('a.cancel-item')
  cancleItemButtons.forEach(function(el) {
    el.addEventListener('click', toggleItemEdit)
  })

  //
  // Handle Shipping Method Edit/Cancel Click
  const editShippingMethodButtons = document.querySelectorAll('a.edit-method')
  const cancleShippingMethodButtons = document.querySelectorAll('a.cancel-method')
  editShippingMethodButtons.forEach(function(el) {
    el.addEventListener('click', toggleMethodEdit)
  })
  cancleShippingMethodButtons.forEach(function(el) {
    el.addEventListener('click', toggleMethodEdit)
  })

  //
  // Handle Tracking Number Edit/Cancel Click
  const editTrackingButtons = document.querySelectorAll('a.edit-tracking')
  const cancleTrackingButtons = document.querySelectorAll('a.cancel-tracking')
  editTrackingButtons.forEach(function(el) {
    el.addEventListener('click', toggleTrackingEdit)
  })
  cancleTrackingButtons.forEach(function(el) {
    el.addEventListener('click', toggleTrackingEdit)
  })

  //
  // handle variant selection, show stock level.
  $('#add_variant_id').change(function () {
    const variantId = parseInt($(this).val(), 10)
    const variant = _.find(window.variants, function (variant) {
      return parseInt(variant.id, 10) === variantId
    })

    const stockDetails = document.querySelector('#stock_details')
    stockDetails.innerHTML = variantStockTemplate({ variant: variant.attributes })

    const addVariantButton = document.querySelector('button.add_variant')
    addVariantButton.addEventListener('click', addVariantFromStockLocation)
  })
})
