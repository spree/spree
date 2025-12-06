import { Controller } from "@hotwired/stimulus"
import TomSelect from 'tom-select/dist/esm/tom-select.complete.js';
import { get } from '@rails/request.js'

export default class extends Controller {
  static values = {
    url: String, // remote URL to fetch options
    options: Array, // JSON array of options
    activeOption: String, // array or single value of selected options,
    emptyOption: { type: String, default: null }, // empty option put at the top of the list
    multiple: { type: Boolean, default: false },
    valueField: { type: String, default: 'id' },
    searchField: { type: String, default: 'name' },
    labelField: { type: String, default: 'name' },
    sortField: { type: String, default: 'name' },
    create: { type: Boolean, default: false },
    remoteSearch: { type: Boolean, default: false }, // this will wait for search input before fetching options
    remoteSearchParams: Object,
    remoteSearchActiveOption: String
  }
  static targets = [ "input" ]

  async connect() {
    this.tomSelectedInitializedEvent = new CustomEvent('tomSelectInitialized', { bubbles: true} )
    if (this.urlValue) {
      if (this.remoteSearchValue) {
        this.initTomSelect()
      } else {
        const response = await get(this.urlValue, { contentType: 'application/json' })

        if (response.ok) {
          const options = await response.json
          this.initTomSelect(options)
        }
      }
    } else {
      this.initTomSelect(this.optionsValue)
    }
  }

  initTomSelect(options = []) {
    const settings = {
      maxOptions: 1500,
      lockOptgroupOrder: true,
      valueField: this.valueFieldValue,
      searchField: this.searchFieldValue,
      labelField: this.labelFieldValue,
      sortField: this.sortFieldValue,
      create: this.createValue,
      onInitialize: () => {
        this.inputTarget.dispatchEvent(this.tomSelectedInitializedEvent)
      }
    }

    if (this.urlValue && this.remoteSearchValue) {
      const loadUrl = this.urlValue
      const searchParams = this.remoteSearchParamsValue

      settings.load = async function(query, callback) {
        const params = new URLSearchParams({ q: query, ...searchParams })
        const url = loadUrl + '?' + params.toString()

        const response = await get(url, { contentType: 'application/json' })

        if (response.ok) {
          const options = await response.json
          options.length > 0 ? callback(options) : callback([])
        } else {
          callback()
        }
      }

      if (this.remoteSearchActiveOptionValue) {
        const items = JSON.parse(this.remoteSearchActiveOptionValue)
        settings.options = items
        settings.items = items.map(item => item.id)
      }
    }

    if (options.length > 0) {
      if (this.emptyOptionValue) {
        let groupedOptions = options.map(function (option) {
          option.group = 'non-empty'
          return option
        })

        groupedOptions.unshift({ group: 'empty', id: ' ', name: this.emptyOptionValue })

        settings.options = groupedOptions
        settings.optgroupField = 'group'
        settings.optgroups = [
          { value: 'empty', label: '' },
          { value: 'non-empty', label: '' }
        ]
      } else {
        settings.options = options
      }
    }

    if (this.multipleValue) {
      settings.maxItems = null
      settings.plugins = ['remove_button']
      if (this.activeOptionValue) settings.items = JSON.parse(this.activeOptionValue)
    } else {
      if (this.activeOptionValue) settings.items = [this.activeOptionValue]
    }

    this.inputTarget.classList.remove('hidden', 'd-none')
    this.select = new TomSelect(this.inputTarget, settings)
  }
}
