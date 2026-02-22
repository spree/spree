import { Controller } from '@hotwired/stimulus'
import debounce from 'spree/core/helpers/debounce'
import GooglePlacesSuggestionsProvider from 'spree/core/helpers/address_autocomplete/google_places_suggestions_provider'

export default class extends Controller {
  static targets = [
    'address1',
    'address2',
    'city',
    'state',
    'zipcode',
    'country',
    'suggestionsBoxContainer',
    'suggestionsBoxList',
    'suggestionsOptionTemplate',
    'autocompleteInputContainer',
    'addressWarning'
  ]
  connect() {
    if (typeof google === 'undefined' || typeof google.maps === 'undefined') {
      console.warn('Google Maps API is not loaded. Please see https://developers.google.com/maps/documentation/javascript/get-api-key for more information.')
      return
    }
    this.googlePlacesSuggestionsProvider = new GooglePlacesSuggestionsProvider()
    this.googlePlacesSuggestionsProvider.connect().then(() => {
      this.selectedCountryIso =
        this.countryTarget.options[this.countryTarget.selectedIndex].dataset.iso
      this.addEventListeners()
    })
  }

  disconnect() {
    this.removeEventListeners()
  }

  countryChanged() {
    this.selectedCountryIso =
      this.countryTarget.options[this.countryTarget.selectedIndex].dataset.iso
  }

  async addressChanged() {
    if (this.address1Target.value.length < 2) {
      this.hideSuggestionsBox()
      return
    }

    const suggestions =
      await this.googlePlacesSuggestionsProvider.getSuggestions(
        this.address1Target.value,
        this.selectedCountryIso
      )
    this.suggestionsCount = suggestions.length
    this.suggestionsBoxListTarget.replaceChildren(
      ...suggestions.map((suggestion) =>
        this.suggestionOptionMarkup(suggestion)
      )
    )
    this.showSuggestionsBox()
  }

  showSuggestionsBox() {
    if (this.suggestionsCount > 0) {
      this.suggestionsBoxContainerTarget.classList.remove('hidden')
      this.suggestionsBoxContainerTarget.classList.add('block')
      this.address1Target.setAttribute('aria-expanded', 'true')
      this.address1Target.setAttribute('autocomplete', 'off')
      this.selectedIndex = -1
      this.address1Target.removeAttribute('aria-activedescendant')
    }
  }

  hideSuggestionsBox() {
    this.selectedIndex = -1
    this.address1Target.setAttribute('aria-expanded', 'false')
    this.address1Target.setAttribute('autocomplete', 'shipping-address-line1')
    this.address1Target.removeAttribute('aria-activedescendant')
    const options = this.suggestionsBoxListTarget.querySelectorAll(
      '.suggestions-option-container'
    )
    options.forEach((option) => {
      option.setAttribute('aria-selected', 'false')
    })
    this.suggestionsBoxContainerTarget.classList.remove('block')
    this.suggestionsBoxContainerTarget.classList.add('hidden')
  }

  async handleSuggestionsBoxListKeyPressed(event) {
    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        if (this.selectedIndex < this.suggestionsCount - 1) {
          this.selectOption(this.selectedIndex + 1)
        } else if (this.suggestionsCount) {
          this.selectOption(0)
        }
        break
      case 'ArrowUp':
        event.preventDefault()
        if (this.selectedIndex > 0) {
          this.selectOption(this.selectedIndex - 1)
        } else if (this.suggestionsCount) {
          this.selectOption(4)
        }
        break
      case 'Enter':
        event.preventDefault()
        const selectedOption = this.suggestionsBoxListTarget.querySelector(
          `[aria-selected="true"]`
        )
        await this.fillAddress(selectedOption.dataset.placeId)
        break
      case 'Tab':
        this.hideSuggestionsBox()
        break
      case 'Escape':
        event.preventDefault()
        this.hideSuggestionsBox()
        break
    }
  }

  async fillAddress(placeID) {
    const placeDetails =
      await this.googlePlacesSuggestionsProvider.getPlaceDetails(placeID)

    if (placeDetails) {
      this.address1Target.value = placeDetails.fullAddress
      this.cityTarget.value = placeDetails.city
      this.zipcodeTarget.value = placeDetails.zipcode

      const stateToSelect = this.stateTarget.querySelector(
        `option[data-abbr="${placeDetails.stateAbbr}"]`
      )
      if (stateToSelect) {
        stateToSelect.selected = true
      }

      if (!placeDetails.hasStreetNumber) {
        this.addressWarningTarget.classList.remove('hidden')
        this.addressWarningTarget.classList.add('flex')
      } else {
        this.addressWarningTarget.classList.remove('flex')
        this.addressWarningTarget.classList.add('hidden')
      }
    }

    this.hideSuggestionsBox()
  }

  suggestionOptionMarkup(suggestion) {
    const optionTemplate = this.suggestionsOptionTemplateTarget
    const newOption = optionTemplate.content.cloneNode(true)
    const optionContainer = newOption.querySelector(
      '.suggestions-option-container'
    )
    optionContainer.id = `suggestions-option-${suggestion.index}`
    optionContainer.dataset.placeId = suggestion.placeID
    optionContainer.setAttribute('aria-label', suggestion.description)
    optionContainer.innerHTML = suggestion.html
    optionContainer.addEventListener('click', async (event) => {
      event.preventDefault()
      await this.fillAddress(suggestion.placeID)
    })
    optionContainer.addEventListener('touchstart', async (event) => {
      event.preventDefault()
      await this.fillAddress(suggestion.placeID)
    })
    return newOption
  }

  hideIfClickedOutside(event) {
    if (event.composedPath().includes(this.autocompleteInputContainerTarget)) {
      return
    } else {
      this.hideSuggestionsBox()
    }
  }

  selectOption(index) {
    const options = this.suggestionsBoxListTarget.querySelectorAll(
      '.suggestions-option-container'
    )
    options.forEach((option) => {
      option.setAttribute('aria-selected', 'false')
    })
    options[index].setAttribute('aria-selected', 'true')
    this.address1Target.setAttribute('aria-activedescendant', options[index].id)
    this.selectedIndex = index
  }

  addEventListeners() {
    this.address1Target.addEventListener(
      'input',
      debounce(this.addressChanged.bind(this))
    )
    this.countryTarget.addEventListener(
      'change',
      this.countryChanged.bind(this)
    )
    this.address1Target.addEventListener(
      'keydown',
      this.handleSuggestionsBoxListKeyPressed.bind(this)
    )
    this.address1Target.addEventListener(
      'focus',
      this.addressChanged.bind(this)
    )
    document.addEventListener('click', this.hideIfClickedOutside.bind(this))
  }

  removeEventListeners() {
    this.address1Target.removeEventListener(
      'input',
      debounce(this.addressChanged.bind(this))
    )
    this.countryTarget.removeEventListener(
      'change',
      this.countryChanged.bind(this)
    )
    this.address1Target.removeEventListener(
      'keydown',
      this.handleSuggestionsBoxListKeyPressed.bind(this)
    )
    this.address1Target.removeEventListener(
      'focus',
      this.addressChanged.bind(this)
    )
    document.removeEventListener('click', this.hideIfClickedOutside.bind(this))
  }
}
