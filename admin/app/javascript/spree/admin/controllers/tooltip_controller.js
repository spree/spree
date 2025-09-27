import {
  autoUpdate,
  computePosition,
  flip,
  offset,
  shift,
} from "@floating-ui/dom"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tooltip"]
  static values = {
    placement: { type: String, default: "top" },
    offset: { type: Number, default: 10 },
    crossAxis: { type: Number, default: 0 },
    alignmentAxis: { type: Number, default: null },
  }

  connect() {
    this._cleanup = null
    this.boundUpdate = this.update.bind(this)
    this._originalWidth = null
    this._isShown = false
    this.startAutoUpdate()
    this.addEventListeners()
    this.prepareTooltip()
  }

  disconnect() {
    this.removeEventListeners()
    this.stopAutoUpdate()
    this.resetTooltip()
  }

  addEventListeners() {
    this.element.addEventListener("mouseenter", this.show)
    this.element.addEventListener("mouseleave", this.hide)
  }

  removeEventListeners() {
    this.element.removeEventListener("mouseenter", this.show)
    this.element.removeEventListener("mouseleave", this.hide)
  }

  prepareTooltip() {
    // Ensure tooltip is rendered offscreen but measurable
    if (this.tooltipTarget) {
      // Save original display
      this._originalDisplay = this.tooltipTarget.style.display
      // Temporarily show tooltip offscreen to measure size
      this.tooltipTarget.style.visibility = "hidden"
      this.tooltipTarget.style.display = "block"
      this.tooltipTarget.style.left = "-9999px"
      this.tooltipTarget.style.top = "-9999px"
      // Force reflow and measure
      this._originalWidth = this.tooltipTarget.offsetWidth
      // Height is now dynamic, so we do not set or store it
      this.tooltipTarget.style.width = `${this._originalWidth}px`
      this.tooltipTarget.style.height = "" // Remove any fixed height
      // Hide again
      this.tooltipTarget.style.display = "none"
      this.tooltipTarget.style.visibility = ""
      this.tooltipTarget.style.left = ""
      this.tooltipTarget.style.top = ""
    }
  }

  resetTooltip() {
    if (this.tooltipTarget) {
      this.tooltipTarget.style.width = ""
      this.tooltipTarget.style.height = ""
      this.tooltipTarget.style.display = this._originalDisplay || ""
    }
  }

  show = () => {
    if (!this._isShown) {
      this.tooltipTarget.style.display = "block"
      this.tooltipTarget.style.visibility = "visible"
      // Set explicit width, but let height be dynamic
      if (this._originalWidth) {
        this.tooltipTarget.style.width = `${this._originalWidth}px`
        this.tooltipTarget.style.height = ""
      }
      this.update() // Ensure immediate update when shown
      this._isShown = true
    }
  }

  hide = () => {
    if (this._isShown) {
      this.tooltipTarget.style.display = "none"
      this.tooltipTarget.style.visibility = ""
      // Keep width set to prevent flicker if quickly re-hovered
      this._isShown = false
    }
  }

  startAutoUpdate() {
    if (!this._cleanup) {
      this._cleanup = autoUpdate(
        this.element,
        this.tooltipTarget,
        this.boundUpdate,
      )
    }
  }

  stopAutoUpdate() {
    if (this._cleanup) {
      this._cleanup()
      this._cleanup = null
    }
  }

  update() {
    // Update position even if not visible, to ensure correct positioning when shown
    computePosition(this.element, this.tooltipTarget, {
      placement: this.placementValue,
      middleware: [
        offset({
          mainAxis: this.offsetValue,
          crossAxis: this.crossAxisValue,
          alignmentAxis: this.alignmentAxisValue,
        }),
        flip(),
        shift({ padding: 5 }),
      ],
    }).then(({ x, y }) => {
      Object.assign(this.tooltipTarget.style, {
        left: `${x}px`,
        top: `${y}px`,
      })
    })
  }
}