import { Controller } from "@hotwired/stimulus"
import Pickr from '@simonwep/pickr'

export default class extends Controller {
  static targets = ["picker", "input", "display", "value"]
  static values = { clear: Boolean, defaultColor: String }

  initialize() {
    this.initPicker();
  }

  initPicker() {
    this.picker = Pickr.create({
      el: this.pickerTarget,
      theme: 'classic',
      default: this.inputTarget.value.length > 0 ? this.inputTarget.value : this.defaultColorValue,
      useAsButton: true,

      components: {
        preview: true,
        opacity: true,
        hue: true,

        interaction: {
          hex: true,
          rgba: true,
          hsla: false,
          hsva: false,
          cmyk: false,
          input: true,
          clear: this.hasClearValue ? this.clearValue : false,
          save: false,
          comparison: false,
        },
      },
    })

    this.picker.on('change', (color, _instance) => {
      this.pickerTarget.style.background = color.toRGBA().toString(0);
      this.inputTarget.value = color.toHEXA().toString()
      this.valueTarget.innerHTML = color.toHEXA().toString()
      this.inputTarget.dispatchEvent(new InputEvent('change'))
    })

    this.picker.on('clear', () => {
      this.pickerTarget.style.background = 'white';
      this.inputTarget.value = '';
      this.valueTarget.innerHTML = '';
      this.inputTarget.dispatchEvent(new InputEvent('change'))
    })
  }
}
