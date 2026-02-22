import { Controller } from "@hotwired/stimulus"
import TomSelect from 'tom-select/dist/esm/tom-select.complete.js';

// this is a very simple autocomplete select controller that uses TomSelect
// by default it does not support remote data fetching or adding new options
// that scenarios are handled in the more robust select_controller.js
export default class extends Controller {
  connect() {
    let selectedValue = this.element.value

    let plugins = []

    if (this.element.multiple) {
      plugins = ['remove_button']
    }

    this.select = new TomSelect(this.element ,{
      create: false,
      maxOptions: this.element.children.length,
      selectOnTab: true,
      allowEmptyOption: false,
      plugins: plugins,
      onItemAdd: function() {
        this.setTextboxValue('')
        this.refreshOptions(false)
      }
    })
    if (!this.element.multiple) {
      this.select.on('type', () => {
        this.select.clear()
      })
      this.select.on('change', (value) => {
        if (value) selectedValue = value
      })
      this.select.on('blur', () => {
        this.select.setValue(selectedValue)
      })
    }
  }
}
