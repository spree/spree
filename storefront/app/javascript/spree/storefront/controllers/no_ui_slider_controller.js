import noUiSlider from 'nouislider'
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    range: Array,
    start: Array
  }

  static targets = ['slider', 'minInput', 'maxInput']

  connect() {
    if (this.sliderTarget.noUiSlider) {
      this.sliderTarget.noUiSlider.destroy()
    }

    const slider = noUiSlider.create(this.sliderTarget, {
      start: this.startValue,
      connect: true,
      step: 1,
      range: {
        min: [this.rangeValue[0]],
        max: [this.rangeValue[1]]
      }
    })
    this.wasSliderChanged = Array(this.startValue.length).fill(false)

    slider.on('update', (values, handle) => {
      if (!this.wasSliderChanged[handle] && parseFloat(values[handle]) === this.rangeValue[handle]) {
        this.wasSliderChanged[handle] = true
        return
      }

      if (handle) {
        this.maxInputTarget.value = parseFloat(values[handle]).toFixed(0)
      } else {
        this.minInputTarget.value = parseFloat(values[handle]).toFixed(0)
      }
    })

    this.minInputTarget.addEventListener('change', (event) => {
      slider.set([event.currentTarget.value, null])
    })

    this.maxInputTarget.addEventListener('change', (event) => {
      slider.set([null, event.currentTarget.value])
    })
  }

  disconnect() {
    if (this.sliderTarget.noUiSlider) {
      this.sliderTarget.noUiSlider.destroy()
    }
  }
}
