import { Controller } from '@hotwired/stimulus'
import { EditorView, basicSetup } from 'codemirror'
import { json } from '@codemirror/lang-json'
import { EditorState } from '@codemirror/state'

export default class extends Controller {
  static targets = ['editor', 'input']
  static values = {
    language: { type: String, default: 'json' }
  }

  connect() {
    const initialValue = this.inputTarget.value || ''

    const extensions = [
      basicSetup,
      EditorView.lineWrapping,
      EditorView.updateListener.of((update) => {
        if (update.docChanged) {
          this.inputTarget.value = update.state.doc.toString()
        }
      })
    ]

    // Add language support based on value
    if (this.languageValue === 'json') {
      extensions.push(json())
    }

    this.editorView = new EditorView({
      doc: initialValue,
      extensions: extensions,
      parent: this.editorTarget
    })

    // Hide the original textarea
    this.inputTarget.style.display = 'none'
  }

  disconnect() {
    if (this.editorView) {
      this.editorView.destroy()
    }
  }
}
