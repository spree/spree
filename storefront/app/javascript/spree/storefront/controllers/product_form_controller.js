import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'submit',
    'option',
    'form',
    'addToWishlist',
    'desktopMediaGallery',
    'productDetails',
    'spinnerTemplate',
    'addToWaitlistForm'
  ]
  static values = {
    noCache: Boolean,
    frameName: String,
    optionsParamName: String,
    requiredOptions: Array,
    selectedVariantDisabled: Boolean,
    variantFromOptionsDisabled: Boolean,
    keepOptionsOpen: Boolean,
    url: String,
    disabled: Boolean
  }

  initialize() {
    this.submitTargetHTML = this.submitTarget.innerHTML
  }

  connect() {
    if (this.hasAddToWishlistTarget && this.variantFromOptionsDisabledValue) {
      const notSelectedOptions = this.getNotSelectedOptions()

      if (notSelectedOptions.length === 0) {
        this.addToWishlistTarget.disabled = true
      }
    }

    if (this.hasDesktopMediaGalleryTarget && this.hasProductDetailsTarget) {
      if (this.desktopMediaGalleryTarget.offsetHeight > 800) {
        this.productDetailsTarget.classList.add('sticky')
        const navHeight = document.querySelector('header.sticky')?.offsetHeight || 0
        this.productDetailsTarget.style.top = `${navHeight}px`
      }
    }

    this.formTarget.addEventListener('submit', this.disableSubmitButton)
    this.submitTargets.forEach((button) => button.addEventListener('turbo-stream-form:submit-end', this.enableForm))
  }

  showNotSelectedOptions = (e) => {
    const notSelectedOptions = this.getNotSelectedOptions()

    if (!notSelectedOptions.length) return

    e.preventDefault()

    notSelectedOptions.forEach((option, index) => {
      const fieldSetElement = this.element.querySelector(`[data-option-id="${option}"]`)
      if (index === 0) {
        const toggleElement = fieldSetElement.querySelector('[data-controller="dropdown"]')
        if (toggleElement) {
          toggleElement.dataset.dropdownOpenValue = true
          e.stopImmediatePropagation()
        }
        fieldSetElement.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'nearest' })
      }
    })

    this.keepOptionsOpenValue = true
  }

  // reload turbo frame when option is selected
  updateVariant(_event) {
    this.submitTarget.disabled = true

    const selectedOptions = []

    this.optionTargets.forEach((option) => {
      if (option.checked) {
        selectedOptions.push(`${option.dataset.optionId}:${option.value}`)
      }
    })

    const url = new URL(this.urlValue.length ? this.urlValue : window.location.href)
    if (this.optionsParamNameValue?.length) {
      url.searchParams.append(this.optionsParamNameValue, selectedOptions.join(','))
    } else {
      url.searchParams.append('options', selectedOptions.join(','))
    }

    if (this.noCacheValue) {
      url.searchParams.append('no_cache', true)
    }

    if (this.frameNameValue?.length) {
      Array.from(document.querySelectorAll(`turbo-frame#${this.frameNameValue}`)).forEach((frame) =>
        frame.setAttribute('src', url)
      )
    } else {
      window.Turbo.visit(url, { frame: 'main-product' })
    }
  }

  disabledValueChanged() {
    if (this.disabledValue) {
      this.submitTarget.disabled = true
      this.submitTarget.innerHTML = this.spinnerTemplateTarget.innerHTML
    } else {
      this.submitTarget.innerHTML = this.submitTargetHTML
      this.submitTarget.disabled = false
    }
  }

  disableSubmitButton = () => {
    this.disabledValue = true
  }

  changeCartToken = (e) => {
    if (this.tokenInput) {
      this.tokenInput.value = e.detail.cartToken
    }
  }

  enableForm = () => {
    this.disabledValue = false
  }

  getNotSelectedOptions() {
    const selectedOptions = new Set()
    this.optionTargets.forEach((option) => {
      if (option.checked) {
        selectedOptions.add(option.dataset.optionId)
      }
    })
    const requiredOptions = new Set(this.requiredOptionsValue)
    return [...requiredOptions].filter((x) => !selectedOptions.has(x))
  }
}
