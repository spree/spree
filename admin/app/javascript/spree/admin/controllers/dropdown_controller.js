import {
  autoUpdate,
  computePosition,
  flip,
  offset,
  shift,
  size,
} from "@floating-ui/dom"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "toggle"]
  static values = {
    placement: { type: String, default: "bottom-start" },
    offset: { type: Number, default: 4 },
  }

  connect() {
    this._cleanup = null
    this.boundUpdate = this.update.bind(this)
    this._isOpen = false
    this._toggleElement = null
  }

  disconnect() {
    this.stopAutoUpdate()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    // Store the toggle element that triggered this action
    this._toggleElement = event.currentTarget

    if (this._isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    if (this._isOpen) return

    this.menuTarget.classList.remove("hidden")
    this._isOpen = true

    // Start automatic positioning
    this.startAutoUpdate()

    // Add event listener to close on outside click
    this._outsideClickHandler = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this._outsideClickHandler)

    // Add event listener to close on escape key
    this._escapeHandler = this.handleEscape.bind(this)
    document.addEventListener("keydown", this._escapeHandler)
  }

  close() {
    if (!this._isOpen) return

    this.menuTarget.classList.add("hidden")
    this._isOpen = false

    // Stop automatic positioning
    this.stopAutoUpdate()

    // Remove event listeners
    if (this._outsideClickHandler) {
      document.removeEventListener("click", this._outsideClickHandler)
      this._outsideClickHandler = null
    }

    if (this._escapeHandler) {
      document.removeEventListener("keydown", this._escapeHandler)
      this._escapeHandler = null
    }
  }

  hide(event) {
    // This method is called from the action: click@window->dropdown#hide
    // Only close if clicking outside the dropdown element
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  handleOutsideClick(event) {
    // Close dropdown if clicking outside
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  startAutoUpdate() {
    if (!this._cleanup) {
      const referenceElement = this.hasToggleTarget ? this.toggleTarget : (this._toggleElement || this.element)
      this._cleanup = autoUpdate(
        referenceElement,
        this.menuTarget,
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
    // Use the toggle target if available, or the stored toggle element, or fall back to the controller element
    const referenceElement = this.hasToggleTarget ? this.toggleTarget : (this._toggleElement || this.element)

    computePosition(referenceElement, this.menuTarget, {
      placement: this.placementValue,
      middleware: [
        offset(this.offsetValue),
        flip({
          fallbackAxisSideDirection: "start",
          padding: 8,
        }),
        shift({ padding: 8 }),
        size({
          apply({ availableWidth, availableHeight, elements }) {
            // Ensure dropdown doesn't exceed viewport
            Object.assign(elements.floating.style, {
              maxWidth: `${availableWidth}px`,
              maxHeight: `${availableHeight}px`,
              overflow: "auto",
            })
          },
          padding: 8,
        }),
      ],
    }).then(({ x, y }) => {
      Object.assign(this.menuTarget.style, {
        left: `${x}px`,
        top: `${y}px`,
        position: "absolute",
      })
    })
  }
}
