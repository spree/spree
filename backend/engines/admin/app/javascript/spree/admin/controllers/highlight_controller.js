import { Controller } from '@hotwired/stimulus'
import hljs from '@highlightjs/cdn-assets/es/core.min.js'
import json from '@highlightjs/cdn-assets/es/languages/json.min.js'

export default class extends Controller {
  static targets = ['code']

  connect() {
    // Register the JSON language
    hljs.registerLanguage('json', json)

    // Highlight all code blocks
    this.codeTargets.forEach((block) => {
      hljs.highlightElement(block)
    })
  }
}
