import NestedForm from '@stimulus-components/rails-nested-form'

export default class extends NestedForm {
  static targets = [
    'target',
    'template',
    'sourceLocationId',
    'destinationLocationId',
    'sourceInput',
    'destinationInput',
    'newVariantAddButton',
    'newVariantStockLocationId',
    'newVariantOmitIds'
  ]

  updateSourceLocation({ target: { value } }) {
    this.newVariantStockLocationIdTarget.value = value
    this.sourceInputTargets.forEach((input) => {
      input.value = value
    })
  }

  updateDestinationLocation({ target: { value } }) {
    const variantAddButtonTooltip = this.newVariantAddButtonTarget.querySelector('.with-tip')

    if (value != '') {
      this.newVariantAddButtonTarget.removeAttribute('disabled')

      this.variantAddButtonTooltipTitle = variantAddButtonTooltip.getAttribute('data-original-title')
      variantAddButtonTooltip.setAttribute('data-original-title', '')
    } else {
      this.newVariantAddButtonTarget.setAttribute('disabled', '')

      if (this.variantAddButtonTooltipTitle)
        variantAddButtonTooltip.setAttribute('data-original-title', this.variantAddButtonTooltipTitle)
    }

    this.destinationInputTargets.forEach((input) => {
      input.value = value
    })
  }

  updateQuantity({
    target: {
      value,
      dataset: { variantId }
    }
  }) {
    this.element.querySelector(`[data-source-movement]:has(input[value='${variantId}']) [data-source-quantity]`).value =
      -parseInt(value)
  }

  add(e) {
    e.preventDefault()

    const selectedVariant = document.querySelector('input[name="stock_transfer[variant_id]"]:checked')
    const selectedVariantId = selectedVariant.value
    const variantImage = selectedVariant.closest('.search-picker__option').querySelector('.variant-image')
    const variantInfo = selectedVariant.closest('.search-picker__option').querySelector('.variant-info')
    const variantName = variantInfo.querySelector('.variant-name')
    variantName.innnerText = variantName.innerText
    this.newVariantOmitIdsTarget.value = [this.newVariantOmitIdsTarget.value, selectedVariantId]
      .filter((v) => v?.length)
      .join(',')

    const content = this.templateTarget.innerHTML
      .replace(/NEW_RECORD/g, new Date().getTime().toString())
      .replace(/NEW_RECORD2/g, new Date().getTime().toString())
      .replace(/VARIANT_ID/g, selectedVariantId)
      .replace(/SOURCE_ID/g, this.sourceLocationIdTarget.value)
      .replace(/DESTINATION_ID/g, this.destinationLocationIdTarget.value)
      .replace(/VARIANT_IMAGE/g, variantImage.innerHTML)
      .replace(/VARIANT_INFO/g, variantInfo.innerHTML)

    this.targetTarget.insertAdjacentHTML('beforebegin', content)

    const event = new CustomEvent('rails-nested-form:add', { bubbles: true })
    this.element.dispatchEvent(event)
  }

  remove(e) {
    super.remove(e)
    const variantId = e.target.dataset.variantId
    this.element.querySelector(`[data-source-movement]:has(input[value='${variantId}'])`).remove()
    this.newVariantOmitIdsTarget.value = this.newVariantOmitIdsTarget.value.split(',').filter((v) => v !== variantId).join(',')
  }
}
