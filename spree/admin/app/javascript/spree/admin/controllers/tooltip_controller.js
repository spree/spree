import {
  autoUpdate,
  computePosition,
  flip,
  offset,
  shift,
} from "@floating-ui/dom"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    placement: { type: String, default: "top" },
    offset: { type: Number, default: 10 },
    crossAxis: { type: Number, default: 0 },
    alignmentAxis: { type: Number, default: null },
  }

  connect() {
    // Find tooltip element by CSS class instead of Stimulus target
    this.tooltip = this.element.querySelector('.tooltip-container')

    // Early return if no tooltip element exists
    if (!this.tooltip) {
      return
    }

    this._cleanup = null
    this.boundUpdate = this.update.bind(this)
    this._originalWidth = null
    this._isShown = false
    this._originalParent = null
    this._originalNextSibling = null
    this._movedToBody = false
    this.startAutoUpdate()
    this.addEventListeners()
    this.prepareTooltip()
  }

  disconnect() {
    if (!this.tooltip) {
      return
    }

    this.removeEventListeners()
    this.stopAutoUpdate()
    this.restoreTooltipPosition()
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
    if (this.tooltip) {
      // Save original display
      this._originalDisplay = this.tooltip.style.display
      // Temporarily show tooltip offscreen to measure size
      this.tooltip.style.visibility = "hidden"
      this.tooltip.style.display = "block"
      this.tooltip.style.left = "-9999px"
      this.tooltip.style.top = "-9999px"
      // Force reflow and measure
      this._originalWidth = this.tooltip.offsetWidth + 10
      // Height is now dynamic, so we do not set or store it
      this.tooltip.style.width = `${this._originalWidth}px`
      this.tooltip.style.height = "" // Remove any fixed height
      // Hide again
      this.tooltip.style.display = "none"
      this.tooltip.style.visibility = ""
      this.tooltip.style.left = ""
      this.tooltip.style.top = ""
    }
  }

  resetTooltip() {
    if (this.tooltip) {
      this.tooltip.style.width = ""
      this.tooltip.style.height = ""
      this.tooltip.style.display = this._originalDisplay || ""
    }
  }

  moveTooltipToBody() {
    if (this.tooltip && this.tooltip.parentNode !== document.body) {
      // Save original position for restoration
      this._originalParent = this.tooltip.parentNode
      this._originalNextSibling = this.tooltip.nextSibling

      // Move tooltip to body to prevent clipping by sidebar overflow
      document.body.appendChild(this.tooltip)
    }
  }

  restoreTooltipPosition() {
    if (this.tooltip && this._originalParent) {
      // Restore tooltip to original position
      if (this._originalNextSibling) {
        this._originalParent.insertBefore(this.tooltip, this._originalNextSibling)
      } else {
        this._originalParent.appendChild(this.tooltip)
      }
      this._originalParent = null
      this._originalNextSibling = null
    }
  }

  show = () => {
    if (!this.tooltip) return

    if (!this._isShown) {
      // Move to body on first show
      if (!this._movedToBody) {
        this.moveTooltipToBody()
        this._movedToBody = true
      }

      this.tooltip.style.display = "block"
      this.tooltip.style.visibility = "visible"
      // Set explicit width, but let height be dynamic
      if (this._originalWidth) {
        this.tooltip.style.width = `${this._originalWidth}px`
        this.tooltip.style.height = ""
      }
      this.update() // Ensure immediate update when shown
      this._isShown = true
    }
  }

  hide = () => {
    if (!this.tooltip) return

    if (this._isShown) {
      this.tooltip.style.display = "none"
      this.tooltip.style.visibility = ""
      // Keep width set to prevent flicker if quickly re-hovered
      this._isShown = false
    }
  }

  startAutoUpdate() {
    if (!this._cleanup && this.tooltip) {
      this._cleanup = autoUpdate(
        this.element,
        this.tooltip,
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
    if (!this.tooltip) return

    // Update position even if not visible, to ensure correct positioning when shown
    computePosition(this.element, this.tooltip, {
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
      if (this.tooltip) {
        Object.assign(this.tooltip.style, {
          left: `${x}px`,
          top: `${y}px`,
        })
      }
    })
  }
}