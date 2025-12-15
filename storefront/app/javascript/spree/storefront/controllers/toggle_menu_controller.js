import { Toggle } from 'tailwindcss-stimulus-components'
import { lockScroll, unlockScroll } from 'spree/core/helpers/scroll_lock'

export default class ToggleMenu extends Toggle {
  static targets = ['toggleable', 'content', 'button']
  static values = ['open']

  connect() {
    super.connect()
    this.setupDynamicHeight()
  }

  disconnect() {
    super.disconnect()
    this.cleanupObservers()
  }

  hide(e) {
    if (this.openValue) {
      super.hide(e)
      this.buttonTarget.classList.remove('menu-open')
    }
  }

  toggle(e) {
    this.updateDynamicHeight()
    super.toggle(e)
    if (this.openValue) {
      this.buttonTarget.classList.add('menu-open')
      setTimeout(() => {
        lockScroll()
      }, 0)
    } else {
      this.buttonTarget.classList.remove('menu-open')
      unlockScroll()
    }
  }

  setupDynamicHeight() {
    this.updateDynamicHeight()
    this.setupObservers()
  }

  updateDynamicHeight() {
    if (!this.hasContentTarget) return
    
    const navElement = this.element.querySelector('nav[aria-label="Top"]')
    const navPaddingBottom = navElement ? 
      parseInt(getComputedStyle(navElement).paddingBottom, 10) || 0 : 0
    
    const contentTopDistance = this.contentTarget.getBoundingClientRect().top
    const calculatedHeight = `calc(100dvh - ${contentTopDistance}px)`
    
    this.contentTarget.style.height = calculatedHeight
    const firstChild = this.contentTarget.firstElementChild
    if (firstChild) {
      firstChild.style.marginTop = `${navPaddingBottom}px`
    }
  }

  setupObservers() {
    const debouncedUpdate = () => {
      clearTimeout(this.updateTimeout)
      this.updateTimeout = setTimeout(() => this.updateDynamicHeight(), 16)
    }

    if (typeof ResizeObserver !== 'undefined') {
      this.resizeObserver = new ResizeObserver(debouncedUpdate)
      const navElement = this.element.querySelector('nav[aria-label="Top"]')
      if (navElement) {
        this.resizeObserver.observe(navElement)
      }
    }

    this.windowResizeHandler = debouncedUpdate
    window.addEventListener('resize', this.windowResizeHandler)
  }

  cleanupObservers() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    if (this.windowResizeHandler) {
      window.removeEventListener('resize', this.windowResizeHandler)
    }
    clearTimeout(this.updateTimeout)
  }

}
