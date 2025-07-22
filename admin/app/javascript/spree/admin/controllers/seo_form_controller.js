import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'titlePreview',
    'slugPreview',
    'descriptionPreview',
    'preview',
    'inputsContainer',
    'titleInput',
    'descriptionInput',
    'slugInput',
    'sourceTitleInput',
    'sourceDescriptionInput',
    'sourceExcerptInput',
    'placeholder'
  ]

  static values = {
    editor: { type: String, default: 'trix' }
  }

  connect() {
    this.sourceTitleInputTarget.addEventListener('input', this.updatePreviews)

    if (this.editorValue == 'tinymce') {
      this.connectTinymceEditor()
    } else {
      this.connectTrixEditors()
    }
  }

  connectTrixEditors() {
    document.addEventListener("trix-initialize", () => {
      if (this.hasSourceDescriptionInputTarget) {
        this.sourceDescriptionEditorTarget = this.sourceDescriptionInputTarget.editor
        this.sourceDescriptionInputTarget.addEventListener('trix-change', this.updatePreviews)

        if (this.hasSourceExcerptInputTarget) {
          this.sourceExcerptEditorTarget = this.sourceExcerptInputTarget.editor
          this.sourceExcerptInputTarget.addEventListener('trix-change', this.updatePreviews)
        }
      }

      this.updatePreviews()
    })
  }

  connectTinymceEditor() {
    const descriptionEditorId = this.sourceDescriptionInputTarget.id

    tinymce.on('AddEditor', (e) => {
      if (e.editor.id !== descriptionEditorId) return
      this.sourceDescriptionEditorTarget = tinymce.get(descriptionEditorId)
      this.sourceDescriptionEditorTarget.on('input', this.updatePreviews)
      this.sourceDescriptionEditorTarget.on('init', this.updatePreviews)
    })
  }

  updatePreviews = () => {
    if (this.metaTitle.trim().length === 0 && this.metaDescription.trim().length === 0) {
      this.titlePreviewTarget.textContent = ''
      this.slugPreviewTarget.textContent = ''
      this.descriptionPreviewTarget.textContent = ''

      this.previewTarget.classList.add('d-none')
      this.placeholderTarget.classList.remove('d-none')

      return
    }

    this.previewTarget.classList.remove('d-none')
    this.placeholderTarget.classList.add('d-none')

    this.titlePreviewTarget.textContent = this.metaTitle
    this.slugPreviewTarget.textContent = this.slugInputTarget.value
    this.descriptionPreviewTarget.textContent = this.metaDescription
  }

  toggleInputs() {
    this.inputsContainerTarget.classList.toggle('d-none')
  }

  get metaTitle() {
    return this.titleInputTarget.value.length ? this.titleInputTarget.value : this.sourceTitleInputTarget.value
  }

  get metaDescription() {
    const metaDescription = this.descriptionInputTarget.value.length
      ? this.descriptionInputTarget.value
      : this.sourceTextEditorContent

    if (metaDescription.length > 320) {
      return metaDescription.substring(0, 320) + '...'
    }

    return metaDescription
  }

  get sourceTextEditorContent() {
    if (!this.hasSourceDescriptionInputTarget) return ''

    if (this.editorValue == 'tinymce') {
      return this.sourceDescriptionEditorTarget.getContent({ format: 'text' })
    } else {
      const descriptionEditorContent = this.sourceDescriptionEditorTarget.getDocument().toString()

      if (this.sourceExcerptEditorTarget) {
        const excerptEditorDocument = this.sourceExcerptEditorTarget.getDocument()
        return excerptEditorDocument.isEmpty() ? descriptionEditorContent : excerptEditorDocument.toString()
      } else {
        return descriptionEditorContent
      }
    }
  }
}
