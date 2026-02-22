import { Controller } from '@hotwired/stimulus'
import TomSelect from 'tom-select/dist/esm/tom-select.complete.js'

export default class extends Controller {
  static values = {
    fontsFromGoogle: Array
  }

  connect() {
    this.prepareLinkTag()
    this.element.classList.remove('hidden', 'd-none')
    this.tomSelect = new TomSelect(this.element, {
      create: false,
      maxOptions: 110,
      render: {
        item: (data, _escape) => {
          return `<div style="font-family: '${data.text}'">${data.text}</div>`
        },
        option: (data, _escape) => {
          return `<div style="font-family: '${data.text}'">${data.text}</div>`
        }
      }
    })
  }

  disconnect() {
    if (this.tomSelect) {
      this.tomSelect.destroy()
    }
    if (this.linkEl) {
      this.linkEl.remove()
    }
  }

  prepareLinkTag() {
    if (
      typeof this.linkEl !== 'undefined' ||
      !this.fontsFromGoogleValue.length ||
      document.getElementById('font-picker-styles')
    ) {
      return
    }
    const fontsAsQueryString = this.fontsFromGoogleValue
      .map((f) => f.replaceAll(' ', '+'))
      .join('&family=')
    const fontsUrl = `https://fonts.googleapis.com/css2?family=${fontsAsQueryString}&display=swap`

    this.linkEl = document.createElement('link')
    this.linkEl.id = 'font-picker-styles'
    this.linkEl.href = fontsUrl
    this.linkEl.rel = 'stylesheet'

    document.head.appendChild(this.linkEl)
  }
}
