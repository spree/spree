import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Watch for new elements being added to this element
    const observer = new MutationObserver(this.handleMutations.bind(this))
    observer.observe(this.element, { childList: true })
    this.observer = observer
  }

  disconnect() {
    this.observer?.disconnect()
  }

  handleMutations(mutations) {
    for (const mutation of mutations) {
      if (mutation.addedNodes.length > 0) {
        // Find the first added node that is not a HTML comment node
        // Rails injects a HTML comments when rendering partials
        const newNode = Array.from(mutation.addedNodes).find(
          node => node.nodeType !== Node.COMMENT_NODE && node.nodeType !== Node.TEXT_NODE
        )
        if (newNode) {
          this.scrollToElement(newNode)
        }
      }
    }
  }

  scrollToElement(element) {
    element.scrollIntoView({ behavior: "smooth", block: "end" })
  }
}