import { Controller } from '@hotwired/stimulus'
import { get } from '@rails/request.js'
import debounce from 'spree/core/helpers/debounce'

export default class extends Controller {
  static targets = ['input']
  static values = {
    url: String
  }

  connect() {
    this.debouncedQuerySuggestions = debounce(this.querySuggestions)
    this.inputTarget.addEventListener('input', this.debouncedQuerySuggestions)
    this.openSearchButton = document.querySelector('#open-search')
    this.openSearchButton.addEventListener('click', this.show)

    this.searchSuggestionsContainer = document.querySelector('#search-suggestions')
    this.searchSuggestionsContent = this.searchSuggestionsContainer.querySelector('#search-suggestions-content')
    this.loadingHTML = this.searchSuggestionsContainer.querySelector('template#loading').innerHTML
    Turbo.StreamActions[`search-suggestions:close`] = this.remoteClose(this)
  }

  remoteClose = (controller) => {
    return function () {
      controller.hide()
    }
  }
  disconnect() {
    delete Turbo.StreamActions[`search-suggestions:close`]
    this.hide()
    this.inputTarget.removeEventListener('input', this.debouncedQuerySuggestions)
    this.openSearchButton.removeEventListener('click', this.show)
  }
  hide = () => {
    this.searchSuggestionsContainer.style.display = 'none'
  }
  clear = () => {
    this.searchSuggestionsContent.innerHTML = ''
    this.searchSuggestionsContent.classList.remove(...this.searchSuggestionsContent.dataset.showClass.split(' '))
    this.searchSuggestionsContent.classList.add('hidden')
    this.element.classList.remove(...this.element.dataset.showClass.split(' '))
  }
  show = () => {
    this.searchSuggestionsContainer.style.display = 'block'
    this.inputTarget.focus()
    const oldInputValue = this.inputTarget.value
    this.inputTarget.value = ''
    this.inputTarget.value = oldInputValue
  }
  querySuggestions = async () => {
    if (this.inputTarget.value.length >= 3 && this.inputTarget.value.trim().length) {
      this.searchSuggestionsContent.innerHTML = this.loadingHTML
      this.searchSuggestionsContent.classList.remove('hidden')
      this.searchSuggestionsContent.classList.add(...this.searchSuggestionsContent.dataset.showClass.split(' '))
      this.element.classList.add(...this.element.dataset.showClass.split(' '))
      await get(`${this.urlValue}?q=${this.inputTarget.value}`, {
        responseKind: 'turbo-stream'
      })
    }
  }
}
