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
  static values = {
    placement: { type: String, default: "bottom-start" },
    offset: { type: Number, default: 4 },
    portal: { type: Boolean, default: true },
  }

  connect() {
    // Find menu and toggle elements by CSS class instead of Stimulus target
    // Try both .dropdown-menu and .dropdown-container for backward compatibility
    this.menu = this.element.querySelector('.dropdown-menu') ||
                this.element.querySelector('.dropdown-container')
    this.toggleBtn = this.element.querySelector('.dropdown-toggle')

    // Early return if no menu element exists
    if (!this.menu) {
      return
    }

    this._cleanup = null
    this.boundUpdate = this.update.bind(this)
    this._isOpen = false
    this._toggleElement = null
    this._originalParent = null
    this._originalNextSibling = null
    this._movedToBody = false
  }

  disconnect() {
    if (!this.menu) return
    this.stopAutoUpdate()
    this.restoreMenuPosition()
  }

  toggle(event) {
    if (!this.menu) {
      return
    }

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
    if (!this.menu || this._isOpen) {
      return
    }

    // Move menu to body on first open to prevent clipping by sidebar overflow
    // Skip if portal is disabled or if inside bulk panel (to preserve Stimulus controller context)
    if (!this._movedToBody && this.shouldPortalToBody()) {
      this.moveMenuToBody()
      this._movedToBody = true
    }

    this.menu.classList.remove("hidden")
    this.menu.style.display = "block"
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
    if (!this.menu || !this._isOpen) return

    this.menu.classList.add("hidden")
    this.menu.style.display = ""
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
    if (!this._cleanup && this.menu) {
      const referenceElement = this.toggleBtn || this._toggleElement || this.element
      this._cleanup = autoUpdate(
        referenceElement,
        this.menu,
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
    if (!this.menu) return

    // Use the toggle button if available, or the stored toggle element, or fall back to the controller element
    const referenceElement = this.toggleBtn || this._toggleElement || this.element

    computePosition(referenceElement, this.menu, {
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
            // Get the element's computed max-width
            const computedStyle = window.getComputedStyle(elements.floating)
            const originalMaxWidth = parseFloat(computedStyle.maxWidth)

            // Use the smaller of availableWidth or original max-width
            const maxWidth = originalMaxWidth && !isNaN(originalMaxWidth)
              ? Math.min(availableWidth, originalMaxWidth)
              : availableWidth

            // Ensure dropdown doesn't exceed viewport or original constraints
            Object.assign(elements.floating.style, {
              maxWidth: `${maxWidth}px`,
              maxHeight: `${availableHeight}px`,
              overflow: "auto",
            })
          },
          padding: 8,
        }),
      ],
    }).then(({ x, y }) => {
      Object.assign(this.menu.style, {
        left: `${x}px`,
        top: `${y}px`,
        position: "absolute",
      })
    })
  }

  shouldPortalToBody() {
    // Don't portal if explicitly disabled via data attribute
    return this.portalValue
  }

  moveMenuToBody() {
    if (this.menu && this.menu.parentNode !== document.body) {
      // Save original position for restoration
      this._originalParent = this.menu.parentNode
      this._originalNextSibling = this.menu.nextSibling

      // Move menu to body to prevent clipping by sidebar overflow
      document.body.appendChild(this.menu)
    }
  }

  restoreMenuPosition() {
    if (this.menu && this._originalParent) {
      // Restore menu to original position
      if (this._originalNextSibling) {
        this._originalParent.insertBefore(this.menu, this._originalNextSibling)
      } else {
        this._originalParent.appendChild(this.menu)
      }
      this._originalParent = null
      this._originalNextSibling = null
    }
  }
}
