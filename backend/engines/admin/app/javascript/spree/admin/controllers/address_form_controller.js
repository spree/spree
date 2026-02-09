import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'country',
    'state',
    'stateName',
    'stateLabel',
    'stateArrow',
    'zipcode'
  ]

  static values = {
    countries: Array,
    states: Array,
    currentStateId: String
  }

  constructor(...args) {
    super(...args)
    this.changeCountry()
  }

  get country() {
    return this.countriesValue.find(
      (country) => country.id == this.countryTarget.value
    )
  }

  get state() {
    return this.statesValue.find((state) => state[1] == this.stateTarget.value)
  }

  get states() {
    return this.statesValue.filter(
      (state) => state[0] == this.countryTarget.value
    )
  }

  changeCountry(_event) {
    var form = document.querySelector('.address-form')
    this.stateTarget.required = this.country.states_required
    this.stateTarget.value = ''
    this.stateTarget.innerHTML = ''

    var allStates = this.stateTarget.parentNode.parentNode
    var stateName = this.stateNameTarget
    var stateSelector = this.stateTarget

    if (this.country.states_required) {
      this.stateLabelTarget.parentNode.parentNode.classList.remove('hidden')
      form.classList.toggle('cols-2', false)

      allStates.classList.remove('hidden')
      allStates.classList.add('flex')
      if (this.states.length > 0) {
        stateSelector.classList.remove('hidden')
        stateName.classList.add('hidden')

        this.states.map((state) => {
          const option = document.createElement('option')
          option.value = state[1]
          option.dataset.abbr = state[2]
          option.text = state[3]

          if (option.value == this.currentStateIdValue) {
            option.selected = true
          }

          this.stateTarget.add(option)
        })
      } else {
        stateName.classList.remove('hidden')
        stateSelector.classList.add('hidden')
      }
    } else {
      form.classList.toggle('cols-2', true)
      allStates.classList.add('hidden')
      allStates.classList.remove('flex')
    }

    this.zipcodeTarget.required = this.country.zipcode_required
    if (this.country.zipcode_required) {
      form.classList.toggle('col-1', false)
      this.zipcodeTarget.parentNode.classList.remove('hidden')
    } else {
      if (!this.country.states_required) {
        form.classList.toggle('col-1', true)
        form.classList.toggle('cols-2', false)
      } else {
        form.classList.toggle('col-1', false)
        form.classList.toggle('cols-2', true)
      }
      this.zipcodeTarget.parentNode.classList.add('hidden')
      this.zipcodeTarget.value = null
    }
  }
}
