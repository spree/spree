import CheckboxSelectAll from 'stimulus-checkbox-select-all'
import { Sortable } from 'sortablejs'
import { get } from '@rails/request.js'

export default class extends CheckboxSelectAll {
  static targets = [
    'optionTemplate',
    'optionValueTemplate',
    'optionsContainer',
    'optionFormTemplate',
    'newOptionForm',
    'newOptionValuesSelectContainer',
    'newOptionValuesSelect',
    'newOptionNameInput',
    'newOptionButton',
    'newOptionButtonLabel',
    'option',
    'variantsContainer',
    'variantTemplate',
    'variantsTable',
    'deleteButton',
    'checkboxAll',
    'checkbox',
    'stockItemsCount'
  ]

  static values = {
    productId: String,
    options: Object,
    availableOptions: Object,
    variants: Array,
    stock: Object,
    prices: Object,
    currentCurrency: String,
    currencies: Array,
    variantIds: Object,
    currentStockLocationId: String,
    stockLocations: Array,
    optionValuesSelectOptions: Array,
    locale: String,
    adminPath: String
  }

  connect() {
    super.connect()
    this.optionNameOptions = this.newOptionNameInputTarget.options
    this.sortable = new Sortable(this.optionsContainerTarget, {
      group: 'options',
      animation: 150,
      onEnd: this.reorderOptions.bind(this),
      handle: '.draggable',
      filter: '.color-option',
      draggable: '.options-creator__option'
    })
    this.ignoredVariants = new Set()
    this.productFormController = this.application.getControllerForElementAndIdentifier(
      this.element.closest('[data-controller*="product-form"]'),
      'product-form'
    )
    this.currentOptionValues = {}

    // Set ignoredVariants to all the variants that are not on the server
    const existingVariantsOnServer = Object.keys(this.variantIdsValue)
    if (existingVariantsOnServer.length > 0) {
      this.ignoredVariants = new Set(
        this.variantsValue
          .map((variant) => variant.internalName)
          .filter((internalName) => !existingVariantsOnServer.includes(internalName))
      )
    }

    this.inventoryFormTarget = document.querySelector('.inventory-form');
  }

  toggleQuantityTracked() {
    this.element.querySelectorAll('.column-quantity').forEach((el) => el.classList.toggle('d-none'))

    this.variantTemplateTarget.content
      .querySelectorAll('.column-quantity')
      .forEach((el) => el.classList.toggle('d-none'))
  }

  toggle(e) {
    super.toggle(e)
    this.toggleDeleteButton()
  }

  refresh() {
    super.refresh()

    // Set indeterminate state for parent checkboxes
    this.element.querySelectorAll('input[id^="parent_checkbox_"]').forEach((checkbox) => {
      checkbox.indeterminate = false
    })

    // Set checked state for parent checkboxes based on the amount of checked children
    const firstOptionKeys = new Set(this.checked.map((c) => c.value.split('/')[0]))
    firstOptionKeys.forEach((key) => {
      const parentCheckbox = this.element.querySelector(`input[id="parent_checkbox_${key}"]`)
      if (!parentCheckbox) return

      const childCheckboxes = Array.from(this.element.querySelectorAll(`input[value^="${key}/"]`))
      const allChildrenChecked = childCheckboxes.length > 0 && childCheckboxes.every((c) => c.checked)

      parentCheckbox.checked = allChildrenChecked
      parentCheckbox.indeterminate = !allChildrenChecked && childCheckboxes.some((c) => c.checked)
    })

    this.toggleDeleteButton()
  }

  toggleDeleteButton() {
    if (this.checked.length > 0) {
      this.deleteButtonTarget.classList.remove('d-none')
    } else {
      this.deleteButtonTarget.classList.add('d-none')
    }
  }

  deleteSelected() {
    const newStockValue = this.stockValue
    const newPricesValue = this.pricesValue
    this.checked.forEach((checkbox) => {
      const internalName = checkbox.value

      this.ignoredVariants.add(internalName)
      const variant = this.variantsContainerTarget.querySelector(`[data-variant-name="${internalName}"]`)

      const nestingLevel = internalName.split('/').length
      if (nestingLevel === 1) {
        const sortedOptions = Object.entries(this.optionsValue).sort((a, b) => a[1].position - b[1].position)
        const firstOptionKey = sortedOptions[0][0]
        const newOptionValues = this.optionsValue[firstOptionKey].values.filter((value) => value.text !== internalName)
        if (newOptionValues.length === 0) {
          const newOptionsValue = this.optionsValue
          delete newOptionsValue[firstOptionKey]
          this.optionsValue = newOptionsValue
          this.removeOption(firstOptionKey)
        } else {
          this.optionsValue = {
            ...this.optionsValue,
            [firstOptionKey]: {
              ...this.optionsValue[firstOptionKey],
              values: newOptionValues
            }
          }

          this.optionsContainerTarget.querySelector(`#option-${firstOptionKey} [data-name="${internalName}"]`).remove()
        }
        checkbox.checked = false
      }

      delete newStockValue[internalName]
      delete newPricesValue[internalName]
      variant.remove()
    })

    this.stockValue = newStockValue
    this.pricesValue = newPricesValue

    this.checkboxAllTarget.checked = false
    this.refresh()
    this.refreshParentInputs()
  }

  reorderOptions(event) {
    const optionId = event.item.id.replace('option-', '')
    const newPosition = event.newDraggableIndex + 1
    const oldPosition = event.oldDraggableIndex + 1
    const options = Object.keys(this.optionsValue).reduce((acc, key) => {
      if (key === optionId) {
        acc[key] = { ...this.optionsValue[key], position: newPosition }
      } else if (newPosition < oldPosition) {
        if (this.optionsValue[key].position >= newPosition && this.optionsValue[key].position < oldPosition) {
          acc[key] = { ...this.optionsValue[key], position: this.optionsValue[key].position + 1 }
        } else {
          acc[key] = this.optionsValue[key]
        }
      } else {
        if (this.optionsValue[key].position > oldPosition && this.optionsValue[key].position <= newPosition) {
          acc[key] = { ...this.optionsValue[key], position: this.optionsValue[key].position - 1 }
        } else {
          acc[key] = this.optionsValue[key]
        }
      }
      return acc
    }, {})
    this.optionsValue = options
  }

  updateShopLocationCountOnHand() {
    const inputs = this.variantsContainerTarget.querySelectorAll(
      `input[data-slot='[stock_items_attributes][${this.currentStockLocationIdValue}][count_on_hand]_input'][name$='[count_on_hand]']`
    )

    const sum = Array.from(inputs).reduce((acc, input) => {
      if (input.value === '') return acc
      return acc + parseInt(input.value)
    }, 0)
    this.stockItemsCountTarget.textContent = sum
  }

  updateStockLocationId({ target: { value: newStockLocationId } }) {
    newStockLocationId = String(newStockLocationId)

    this.currentStockLocationIdValue = newStockLocationId
    this.stockLocationsValue.forEach((stockLocationId) => {
      this.variantsContainerTarget
        .querySelectorAll(`input[data-slot='[stock_items_attributes][${stockLocationId}][count_on_hand]_input']`)
        .forEach((el) => {
          if (stockLocationId === newStockLocationId) {
            el.classList.remove('d-none')
            el.classList.add('d-block')
          } else {
            el.classList.remove('d-block')
            el.classList.add('d-none')
          }
        })
    })
    this.updateShopLocationCountOnHand()
  }

  updateCurrency({ target: { value: newCurrency } }) {
    this.currentCurrencyValue = newCurrency
    this.currenciesValue.forEach((currency) => {
      this.variantsContainerTarget
        .querySelectorAll(
          `.price-input-container:has(input[data-slot="[prices_attributes][${currency}][amount]_input"])`
        )
        .forEach((el) => {
          if (currency === newCurrency) {
            el.classList.remove('d-none')
            el.classList.add('d-flex')
          } else {
            el.classList.remove('d-flex')
            el.classList.add('d-none')
          }
        })
    })
  }

  optionsValueChanged(value, previousValue) {
    let hasNoOptions = true

    if (this.hasNewOptionButtonTarget) {
      const label = this.newOptionButtonLabelTarget

      if (Object.values(value).filter(Boolean).length) {
        label.textContent = label.dataset.hasOptionsText
        hasNoOptions = false
      } else {
        label.textContent = label.dataset.noOptionsText
      }
    }
    this.refreshOptionNameSelect()
    this.variantsValue = this.generateVariants(value)

    this.toggleInventoryForm(hasNoOptions)

    // We want to clear the ignoredVariants when the options change
    if (previousValue && Object.keys(previousValue).length === 0) return
    this.ignoredVariants = new Set()
  }

  calculateVariantName(variant, keys, i) {
    let name = ''
    let internalName = name
    if (i === 0) {
      name = variant[keys[i]].text
      internalName = name
    } else {
      const namesPath = keys.slice(1, keys.length).map((key) => variant[key].text)
      name = namesPath.join(' / ')
      internalName = `${variant[keys[0]].text}/${namesPath.join('/')}`
    }

    return { name, internalName }
  }

  updateParentCountOnHand(event) {
    const { variantName } = event.target.closest('[data-variants-form-target="variant"]').dataset
    const stockLocationId = event.target.dataset.stockLocationId
    const childrenCountOnHand = this.variantsContainerTarget.querySelectorAll(
      `[data-variant-name^="${variantName}/"] input[data-slot="[stock_items_attributes][${stockLocationId}][count_on_hand]_input"]`
    )
    const parentCountOnHand = event.target.value

    childrenCountOnHand.forEach((countOnHandInput) => {
      countOnHandInput.value = parentCountOnHand
    })

    const childrenCountOnHandKeys = this.variantsValue
      .filter((variant) => variant.internalName.startsWith(variantName))
      .map((variant) => variant.internalName)

    childrenCountOnHandKeys.forEach((key) => {
      this.updateStockItemForVariant(key, { count_on_hand: parentCountOnHand }, stockLocationId)
    })

    this.updateShopLocationCountOnHand()
  }

  updateParentPrice(event) {
    const { variantName } = event.target.closest('[data-variants-form-target="variant"]').dataset
    const currency = event.target.dataset.currency
    const childrenPrices = this.variantsContainerTarget.querySelectorAll(
      `[data-variant-name^="${variantName}/"] input[data-slot="[prices_attributes][${currency}][amount]_input"]`
    )
    const parentPrice = event.target.value

    childrenPrices.forEach((priceInput) => {
      priceInput.value = parentPrice
    })
    const childrenPricesKeys = this.variantsValue
      .filter((variant) => variant.internalName.startsWith(variantName))
      .map((variant) => variant.internalName)

    childrenPricesKeys.forEach((key) => {
      this.updatePriceForVariant(key, parentPrice, currency)
    })
  }

  selectChildVariants(event) {
    const { variantName } = event.target.closest('[data-variants-form-target="variant"]').dataset

    const children = this.variantsContainerTarget.querySelectorAll(
      `[data-variant-name^="${variantName}/"] input[type="checkbox"]`
    )

    children.forEach((child) => {
      child.checked = event.target.checked
    })

    this.refresh()
  }

  prepareParentVariant(existingVariant, internalName) {
    this.currenciesValue.forEach((currency) => {
      const parentPriceInput = existingVariant.querySelector(
        `input[data-slot="[prices_attributes][${currency}][amount]_input"]`
      )
      parentPriceInput.name = ''
      parentPriceInput.dataset.action = `input->variants-form#updateParentPrice`
    })
    this.stockLocationsValue.forEach((stockLocationId) => {
      const parentCountOnHandInput = existingVariant.querySelector(
        `input[data-slot="[stock_items_attributes][${stockLocationId}][count_on_hand]_input"]`
      )
      parentCountOnHandInput.name = ''
      parentCountOnHandInput.dataset.action = 'input->variants-form#updateParentCountOnHand'
    })

    const checkbox = existingVariant.querySelector('input[type="checkbox"][id^="checkbox_"]')
    if (!checkbox) return
    const checkboxLabel = existingVariant.querySelector('label[for^="checkbox_"]')
    checkbox.id = `parent_checkbox_${internalName}`
    checkboxLabel.htmlFor = `parent_checkbox_${internalName}`
    checkbox.dataset.action = 'click->variants-form#selectChildVariants'
    checkbox.value = internalName
  }

  updatePrice(event) {
    const { variantName } = event.target.closest('[data-variants-form-target="variant"]').dataset
    const currency = event.target.dataset.currency
    const nestingLevel = variantName.split('/').length
    this.updatePriceForVariant(variantName, event.target.value, currency)
    if (nestingLevel > 1) {
      const parentName = variantName.split('/')[0]
      this.updateParentPriceRange(parentName, currency)
    }
  }

  replaceBlankWithZero(event) {
    if (event.target.value === '') {
      event.target.value = 0
    }
  }

  updateCountOnHand(event) {
    const variantEl = event.target.closest('[data-variants-form-target="variant"]')
    const variantName = variantEl.dataset.variantName

    const nestingLevel = variantName.split('/').length
    const stockLocationId = event.target.dataset.stockLocationId
    const countOnHand = event.target.value || 0

    this.updateStockItemForVariant(variantName, { count_on_hand: countOnHand }, stockLocationId)

    if (nestingLevel > 1) {
      const parentName = variantName.split('/')[0]
      this.updateParentStockSum(parentName, stockLocationId)
    }

    this.updateShopLocationCountOnHand()
  }

  updateParentPriceRange(variantName, currency) {
    const parentPriceEl = this.variantsContainerTarget.querySelector(
      `div:not(.nested)[data-variant-name="${variantName}"] [data-slot="[prices_attributes][${currency}][amount]_input"]`
    )
    if (!parentPriceEl) return

    const currentVariantKeys = Array.from(
      this.variantsContainerTarget.querySelectorAll(`[data-variant-name^="${variantName}/"]`)
    ).map((el) => el.dataset.variantName)

    const pricesVariation = new Set(
      Object.keys(this.pricesValue)
        .filter((key) => currentVariantKeys.includes(key))
        .map((key) => this.priceForVariant(key, currency).amount)
    )

    pricesVariation.delete(null)

    if (pricesVariation.size === 0) {
      parentPriceEl.value = this.priceForVariant(variantName, currency).amount?.toLocaleString(this.localeValue) || ''
      parentPriceEl.placeholder = ''
      return
    }
    const minPrice = Math.min(...pricesVariation)
    const maxPrice = Math.max(...pricesVariation)

    if (minPrice !== maxPrice) {
      parentPriceEl.value = null
      parentPriceEl.placeholder = `${minPrice} - ${maxPrice}`
    } else {
      parentPriceEl.value = minPrice
    }
  }

  updateParentStockSum(variantName, stockLocationId) {
    const parentStockEl = this.variantsContainerTarget.querySelector(
      `div:not(.nested)[data-variant-name="${variantName}"] [data-slot="[stock_items_attributes][${stockLocationId}][count_on_hand]_input"]`
    )
    if (!parentStockEl) return

    const currentVariantKeys = Array.from(
      this.variantsContainerTarget.querySelectorAll(`[data-variant-name^="${variantName}/"]`)
    ).map((el) => el.dataset.variantName)

    if (currentVariantKeys.length === 0) {
      parentStockEl.value = this.stockItemForVariant(variantName, stockLocationId).count_on_hand
      parentStockEl.placeholder = ''
      this.updateShopLocationCountOnHand()
      return
    }

    const countsOnHand = Object.keys(this.stockValue)
      .filter((key) => currentVariantKeys.includes(key))
      .map((key) => this.stockItemForVariant(key, stockLocationId).count_on_hand)

    const sum = countsOnHand.reduce((acc, value) => acc + parseInt(value) || 0, 0)

    parentStockEl.placeholder = String(sum)
    parentStockEl.value = null
  }

  variantsValueChanged() {
    let keys = Object.keys(this.variantsValue[0] || {}).filter((key) => key !== 'internalName')

    const currentVariants = new Set()

    if (keys.length) {
      this.variantsTableTarget.classList.remove('d-none')

      const nestingLevel = Math.min(keys.length, 2)
      let idx = 0

      for (let i = 0; i < nestingLevel; i++) {
        this.variantsValue.forEach((variant) => {
          const { name, internalName } = this.calculateVariantName(variant, keys, i)
          if (currentVariants.has(internalName) || this.ignoredVariants.has(internalName)) {
            idx++
            return
          }
          currentVariants.add(internalName)

          const existingVariant = this.variantsContainerTarget.querySelector(`[data-variant-name="${internalName}"]`)
          if (existingVariant) {
            if (i === 0 && nestingLevel > 1) {
              existingVariant.querySelectorAll("input[type='hidden']").forEach((input) => input.remove())

              this.prepareParentVariant(existingVariant, internalName)
            }
            idx++
            return
          }

          const template = this.variantTemplateTarget.content.cloneNode(true)
          const variantNameContainer = template.querySelector('[data-slot="variantName"]')
          const variantTarget = template.querySelector('[data-variants-form-target="variant"]')
          variantTarget.dataset.variantName = internalName

          const variantId = this.variantIdsValue[internalName]
          if (variantId) {
            const variantEditButton = variantTarget.querySelector('[data-slot="variantEditButton"]')

            if (variantEditButton) {
              variantEditButton.href = `${Spree.adminPath}/products/${this.productIdValue}/variants/${variantId}/edit`
              variantEditButton.classList.remove('invisible')
            }
          }

          let previousVariant = null

          if (i > 0) {
            const { internalName: parentInternalName } = this.calculateVariantName(variant, keys, 0)
            const variantsInThisGroup = this.variantsContainerTarget.querySelectorAll(
              `[data-variant-name^="${parentInternalName}/"]`
            )
            if (variantsInThisGroup.length > 0) {
              // If there are already variants in this option type then we want to render this variant after the last variant in the group
              previousVariant = variantsInThisGroup[variantsInThisGroup.length - 1]
            } else {
              // Otherwise we want to render this variant after the parent variant
              previousVariant = this.variantsContainerTarget.querySelector(
                `[data-variant-name="${parentInternalName}"]`
              )
            }
            variantTarget.classList.add('nested')
          } else if (nestingLevel > 1) {
            template.querySelectorAll("input[type='hidden']").forEach((input) => input.remove())
            this.prepareParentVariant(template, internalName)
          }

          if (i === nestingLevel - 1) {
            const inputs = this.createInputsForVariant(keys, variant, idx)
            inputs.forEach((input) => {
              variantTarget.appendChild(input)
            })

            const checkbox = template.querySelector('input[type="checkbox"]#checkbox_')
            if (checkbox) {
              const checkboxLabel = template.querySelector('label[for="checkbox_"]')
              checkbox.id = `checkbox_${internalName}`
              checkboxLabel.htmlFor = `checkbox_${internalName}`
              checkbox.value = internalName
            }

            this.preparePriceInputs(variantTarget, internalName, idx)

            this.prepareStockInputs(variantTarget, internalName, idx)
          }
          idx++

          variantNameContainer.textContent = name
          if (previousVariant) {
            previousVariant.after(template)
          } else {
            this.variantsContainerTarget.appendChild(template)
          }
        })
      }
    } else {
      this.variantsTableTarget.classList.add('d-none')
    }

    this.variantsContainerTarget.querySelectorAll('[data-variants-form-target="variant"]').forEach((variant) => {
      const variantName = variant.dataset.variantName
      if (!currentVariants.has(variantName)) {
        variant.remove()
      }
    })

    // When going back from variant edit page the `variantsValueChanged` method is called before the `connect` method, so `this.productFormController` is not set yet
    if (this.productFormController) {
      this.productFormController.hasVariantsValue = this.variantsValue.length > 0
    }

    this.refreshParentInputs()
  }

  refreshParentInputs() {
    const firstOption = Object.values(this.optionsValue)[0]
    if (firstOption) {
      firstOption.values.forEach((option) => {
        this.currenciesValue.forEach((currency) => {
          this.updateParentPriceRange(option.text, currency)
        })
        this.stockLocationsValue.forEach((stockLocationId) => {
          this.updateParentStockSum(option.text, stockLocationId)
        })
        this.updateShopLocationCountOnHand()
      })
    }
  }

  createInputsForVariant(keys, variant, i) {
    const inputs = []
    if (this.variantIdsValue[variant.internalName]) {
      const idInput = document.createElement('input')
      idInput.type = 'hidden'
      idInput.name = `product[variants_attributes][${i}][id]`
      idInput.value = this.variantIdsValue[variant.internalName]
      inputs.push(idInput)
    }

    keys.forEach((key) => {
      const idInput = document.createElement('input')
      idInput.type = 'hidden'
      idInput.name = `product[variants_attributes][${i}][options][][id]`
      idInput.value = Object.entries(this.optionsValue).find((option) => option[1].name === key)?.[0]
      inputs.push(idInput)

      const nameInput = document.createElement('input')
      nameInput.type = 'hidden'
      nameInput.name = `product[variants_attributes][${i}][options][][name]`
      nameInput.value = key
      inputs.push(nameInput)

      const positionInput = document.createElement('input')
      positionInput.type = 'hidden'
      positionInput.name = `product[variants_attributes][${i}][options][][position]`
      positionInput.value = Object.values(this.optionsValue)
        .filter(Boolean)
        .find((option) => option.name === key).position
      inputs.push(positionInput)

      const optionNameInput = document.createElement('input')
      optionNameInput.type = 'hidden'
      optionNameInput.name = `product[variants_attributes][${i}][options][][option_value_name]`
      optionNameInput.value = variant[key].value
      inputs.push(optionNameInput)

      const optionIdInput = document.createElement('input')
      optionIdInput.type = 'hidden'
      optionIdInput.name = `product[variants_attributes][${i}][options][][option_value_presentation]`
      optionIdInput.value = variant[key].text
      inputs.push(optionIdInput)
    })

    return inputs
  }

  prepareStockInputs(variantTarget, internalName, idx) {
    this.stockLocationsValue.forEach((stockLocationId) => {
      const stockInput = variantTarget.querySelector(
        `input[data-slot="[stock_items_attributes][${stockLocationId}][count_on_hand]_input"]`
      )
      const stockIdInput = variantTarget.querySelector(
        `input[data-slot="[stock_items_attributes][${stockLocationId}][id]_input"]`
      )
      const stockLocationIdInput = variantTarget.querySelector(
        `input[data-slot="[stock_items_attributes][${stockLocationId}][stock_location_id]_input"]`
      )
      let stockItem = this.stockItemForVariant(internalName, stockLocationId)
      if (!stockItem.id) {
        const oldInternalName = internalName.split('/').slice(0, -1).join('/')
        const oldStock = this.stockItemForVariant(oldInternalName, stockLocationId).count_on_hand ?? 0

        stockItem.count_on_hand = oldStock

        this.updateStockItemForVariant(internalName, stockItem, stockLocationId)
      }

      stockInput.name = `product[variants_attributes][${idx}][stock_items_attributes][${stockLocationId}][count_on_hand]`
      stockLocationIdInput.name = `product[variants_attributes][${idx}][stock_items_attributes][${stockLocationId}][stock_location_id]`
      stockIdInput.name = `product[variants_attributes][${idx}][stock_items_attributes][${stockLocationId}][id]`

      stockInput.value = stockItem.count_on_hand
      if (String(stockLocationId) === String(this.currentStockLocationIdValue)) {
        stockInput.classList.remove('d-none')
        stockInput.classList.add('d-block')
      } else {
        stockInput.classList.remove('d-block')
        stockInput.classList.add('d-none')
      }
      if (stockItem.id) {
        stockIdInput.value = stockItem.id
      }
    })
  }

  preparePriceInputs(variantTarget, internalName, idx) {
    this.currenciesValue.forEach((currency, currencyIndex) => {
      const priceInput = variantTarget.querySelector(
        `input[data-slot="[prices_attributes][${currency}][amount]_input"]`
      )
      const currencyInput = variantTarget.querySelector(
        `input[data-slot="[prices_attributes][${currency}][currency]_input"]`
      )
      const idInput = variantTarget.querySelector(`input[data-slot="[prices_attributes][${currency}][id]_input"]`)
      priceInput.name = `product[variants_attributes][${idx}][prices_attributes][${currency}]`
      if (currency === this.currentCurrencyValue) {
        priceInput.parentElement.classList.remove('d-none')
        priceInput.parentElement.classList.add('d-flex')
      } else {
        priceInput.parentElement.classList.remove('d-flex')
        priceInput.parentElement.classList.add('d-none')
      }

      const existingPrice = this.priceForVariant(internalName, currency)
      priceInput.value = existingPrice.amount?.toLocaleString(this.localeValue) || ''
      currencyInput.value = currency
      if (existingPrice.id) {
        idInput.value = existingPrice.id
      }

      priceInput.name = `product[variants_attributes][${idx}][prices_attributes][${currencyIndex}][amount]`
      currencyInput.name = `product[variants_attributes][${idx}][prices_attributes][${currencyIndex}][currency]`
      idInput.name = `product[variants_attributes][${idx}][prices_attributes][${currencyIndex}][id]`
    })
  }

  addOption(name, option_values = [], id) {
    let color = false
    let position = Object.keys(this.optionsValue).length + 1
    let newOptionsPositions = {}

    const template = this.optionTemplate(name, option_values, id, color)

    this.optionsValue = {
      ...this.optionsValue,
      ...newOptionsPositions,
      [id]: {
        name,
        values: option_values,
        position: position
      }
    }

    if (position === 1) {
      this.optionsContainerTarget.prepend(document.importNode(template, true))
    } else {
      this.optionsContainerTarget.appendChild(document.importNode(template, true))
    }
  }

  // After selecting an option name (eg. "Color"), we fetch the option values for that option name and update the tom select options
  async handleSelectedOptionName(event) {
    const targetInput = event.target
    this.lastOptionNameId = targetInput.value

    if (this.lastOptionNameId) {
      const response = await get(`${this.adminPathValue}/option_types/${this.lastOptionNameId}/option_values/select_options`)

      if (response.ok) {
        this.currentOptionValues[this.lastOptionNameId] = await response.json

        const optionsCreatorContainer = targetInput.closest('.options-creator__option')
        const newOptionValuesSelects = optionsCreatorContainer.querySelectorAll('[data-variants-form-target="newOptionValuesSelect"]')

        newOptionValuesSelects.forEach((select) => this.replaceSelectOptions(select))
      }
    }
  }

  replaceSelectOptions(select) {
    const tomSelect = select.tomselect

    if (tomSelect) {
      tomSelect.clear()
      tomSelect.clearOptions()
      tomSelect.addOptions(this.currentOptionValues[this.lastOptionNameId])
    }
  }

  newOptionValuesSelectTargetConnected(select) {
    if (this.lastOptionNameId)
      this.replaceSelectOptions(select)
  }

  handleNewOption(_event) {
    const newOptionName = this.newOptionNameInputTarget.options[this.newOptionNameInputTarget.selectedIndex].text
    const newOptionId = String(this.newOptionNameInputTarget.value)
    const newOptionValues = this.newOptionValuesSelectContainerTarget.values()

    if (
      !newOptionName.length ||
      this.optionsValue[newOptionId] ||
      newOptionValues.length === 0 ||
      Object.values(this.optionsValue)
        .filter(Boolean)
        .map((v) => v.name)
        .includes(newOptionName)
    ) {
      return
    }

    this.addOption(newOptionName, newOptionValues, newOptionId)

    this.hideNewOptionForm()

    this.toggleInventoryForm(false)
  }

  hideNewOptionForm() {
    this.newOptionNameInputTarget.tomselect.clear()
    this.newOptionValuesSelectContainerTarget.reset()

    this.newOptionFormTarget.classList.add('d-none')

    this.newOptionButtonTarget.classList.remove('d-none')
  }

  editOption(event) {
    let { optionId } = event.params
    optionId = String(optionId)

    const option = this.optionsContainerTarget.querySelector(`#option-${optionId}`)

    const { name, values } = this.optionsValue[optionId]
    const availableOptions = this.availableOptionsValue[optionId] || this.currentOptionValues[optionId]?.map((option) => ({ id: option.id, name: option.name }))

    const form = this.optionFormTemplate(name, values, optionId, availableOptions)

    option.replaceWith(form)

    // Disable the option name in the select tag that is already picked
    const optionContainer = this.optionsContainerTarget.querySelector(`#option-${optionId}`)
    const optionNameSelect = optionContainer.querySelector('select[name="option_name"]')
    const options = Array.from(optionNameSelect.options)

    const alreadySelectedOptions = Object.keys(this.optionsValue).filter((k) => this.optionsValue[k] !== null)
    const optionsToDisable = options.filter((option) => option.text != name && alreadySelectedOptions.includes(option.value))

    optionsToDisable.forEach((option) => option.disabled = true)
  }

  saveOption(event) {
    let { optionId } = event.params
    optionId = String(optionId)

    const option = this.optionsContainerTarget.querySelector(`#option-${optionId}`)
    const optionForm = option.closest('[data-slot="optionForm"]')
    const optionNameSelect = option.querySelector('select[name="option_name"]')
    const optionName = optionNameSelect.options[optionNameSelect.selectedIndex].text
    const newId = String(optionNameSelect.value)

    if ((newId != optionId && this.optionsValue[newId]) || !optionName.length) {
      return
    }

    let color = false
    let position = this.optionsValue[optionId].position
    let newOptionsPositions = {}

    const optionValues = option.querySelector('[data-slot="optionValuesSelectContainer"]').values()

    if (optionValues.length === 0) {
      return
    }

    const template = this.optionTemplate(optionName, optionValues, newId, color)

    if (color) {
      this.optionsContainerTarget.prepend(template)
      optionForm.remove()
    } else {
      optionForm.replaceWith(template)
    }

    const newOptions = {
      ...this.optionsValue,
      ...newOptionsPositions,
      [newId]: {
        ...this.optionsValue[optionId],
        name: optionName,
        values: optionValues,
        position: position
      }
    }
    if (optionId != newId) {
      delete newOptions[optionId]
    }

    this.optionsValue = newOptions
  }

  showNewOptionForm(event) {
    event.preventDefault()
    this.newOptionFormTarget.classList.remove('d-none')
    this.newOptionButtonTarget.classList.add('d-none')
    this.refreshOptionNameSelect()
  }

  optionTemplate(name, values, id, color = false) {
    const template = this.optionTemplateTarget.content.cloneNode(true)
    template.querySelectorAll('[data-variants-form-option-id-param]').forEach((el) => {
      el.dataset.variantsFormOptionIdParam = id
    })
    const optionName = template.querySelector('[data-slot="optionName"]')
    const optionValuesTemplates = this.optionValueTemplate(values)
    const optionValuesContainer = template.querySelector('[data-slot="optionValuesContainer"]')
    optionValuesTemplates.forEach((optionValueTemplate) => {
      optionValuesContainer.appendChild(optionValueTemplate)
    })
    const mainContainer = template.querySelector('[data-variants-form-target="option"]')
    mainContainer.id = `option-${id}`

    optionName.textContent = name
    if (color) {
      mainContainer.classList.add('color-option')
      mainContainer.querySelector('.draggable').disabled = true
    }
    return template
  }

  discardOption(event) {
    let { optionId } = event.params
    optionId = String(optionId)

    this.removeOption(optionId)

    const newOptionsValue = {}
    Object.entries(this.optionsValue).filter((option) => option[0] !== optionId).forEach((option) => {
      newOptionsValue[option[0]] = option[1]
    })

    this.optionsValue = newOptionsValue
    this.refreshParentInputs()
  }

  removeOption(optionId) {
    const option = this.optionsContainerTarget.querySelector(`#option-${optionId}`)
    if (option) option.remove()
  }

  optionFormTemplate(optionName, optionValues, id, availableOptions) {
    const template = this.optionFormTemplateTarget.content.cloneNode(true)

    const optionNameSelect = template.querySelector('select[name="option_name"]')

    let optionExists = false
    // If options includes the optionName, set it as selected
    optionNameSelect.querySelectorAll('option').forEach((option) => {
      if (String(option.value) === id) {
        option.selected = true
        optionExists = true
      }
    })
    // Otherwise, create a new option, and select it
    if (!optionExists) {
      const newOption = document.createElement('option')
      newOption.text = optionName
      newOption.value = id
      newOption.selected = true
      optionNameSelect.appendChild(newOption)
    }

    const optionValuesSelectContainer = template.querySelector('[data-slot="optionValuesSelectContainer"]')
    const tomSelectOptionValues = optionValues.map((optionValue) => {
      return {
        id: optionValue.value,
        name: optionValue.text,
      }
    })

    optionValuesSelectContainer.setAttribute('data-multi-tom-select-preloaded-options-value', JSON.stringify(availableOptions))
    optionValuesSelectContainer.setAttribute('data-multi-tom-select-preloaded-values-value', JSON.stringify(tomSelectOptionValues))

    template.querySelectorAll('[data-variants-form-option-id-param]').forEach((el) => {
      el.dataset.variantsFormOptionIdParam = id
    })

    const mainContainer = template.querySelector('[data-slot="optionForm"]')
    mainContainer.id = `option-${id}`

    return template
  }

  optionValueTemplate(values) {
    const templates = []

    values.forEach((value) => {
      const template = this.optionValueTemplateTarget.content.cloneNode(true)
      const optionValueNameEl = template.querySelector('[data-slot="optionValueName"]')
      optionValueNameEl.textContent = value.text
      optionValueNameEl.dataset.name = value.text

      templates.push(template)
    })

    return templates
  }

  refreshOptionNameSelect() {
    const alreadySelectedOptions = Object.keys(this.optionsValue).filter((k) => this.optionsValue[k] !== null)

    Array.from(this.newOptionNameInputTarget.options).forEach((option) => {
      const tomSelect = this.newOptionNameInputTarget.tomselect
      if (!tomSelect) return

      const tomselectOption = tomSelect.getOption(option.value)
      if (!tomselectOption) return

      const alreadySelected = alreadySelectedOptions.includes(option.value)
      tomselectOption.ariaDisabled = alreadySelected

      if (alreadySelected) {
        tomselectOption.removeAttribute('data-selectable')
      } else {
        tomselectOption.setAttribute('data-selectable', '')
      }

      tomselectOption.disabled = alreadySelected
    })

    const optionNameTomSelect = this.newOptionNameInputTarget.tomselect

    if (optionNameTomSelect) {
      optionNameTomSelect.sync()
      optionNameTomSelect.refreshOptions(false)
    }
  }

  generateVariants(optionsValue) {
    const options = Object.values(optionsValue)
      .filter(Boolean)
      .sort((a, b) => a.position - b.position)

    if (options.length === 0) {
      return []
    }

    const optionValues = options.map((option) => option.values)
    const optionNames = options.map((option) => option.name)

    const cartesianProduct = this.cartesianProduct(optionValues)

    return cartesianProduct.map((variant) => {
      variant = Array.isArray(variant) ? variant : [variant]
      const variantObj = variant.reduce((acc, value, index) => {
        acc[options[index].name] = value
        return acc
      }, {})
      variantObj.internalName = this.calculateVariantName(variantObj, optionNames, optionNames.length - 1).internalName
      return variantObj
    })
  }

  cartesianProduct(arr) {
    return arr.reduce((a, b) => a.flatMap((d) => b.map((e) => [d, e].flat())))
  }

  stockItemForVariant(variantName, stockLocationId) {
    const existingStock = this.stockValue[variantName]?.[String(stockLocationId)]
    if (existingStock) return existingStock

    return { count_on_hand: 0, backorderable: false, id: null }
  }

  updateStockItemForVariant(variantName, newStockItem, stockLocationId) {
    const existingStockItem = this.stockItemForVariant(variantName, stockLocationId)
    this.stockValue = {
      ...this.stockValue,
      [variantName]: {
        ...this.stockValue[variantName],
        [stockLocationId]: {
          ...existingStockItem,
          ...newStockItem
        }
      }
    }
  }

  priceForVariant(variantName, currency) {
    const existingPrice = this.pricesValue[variantName]?.[currency.toLowerCase()]
    if (existingPrice) {
      return {
        ...existingPrice,
        amount: existingPrice.amount ? parseFloat(existingPrice.amount) : existingPrice.amount
      }
    }

    return { amount: null, id: null }
  }

  updatePriceForVariant(variantName, newPrice, currency) {
    const existingPrice = this.priceForVariant(variantName, currency)
    this.pricesValue = {
      ...this.pricesValue,
      [variantName]: {
        ...this.pricesValue[variantName],
        [currency.toLowerCase()]: {
          ...existingPrice,
          amount: parseFloat(newPrice)
        }
      }
    }
  }

  toggleInventoryForm(value) {
    if (!this.inventoryFormTarget) return

    if (value) {
      this.inventoryFormTarget.classList.remove('d-none')
    } else {
      this.inventoryFormTarget.classList.add('d-none')
    }
  }
}
