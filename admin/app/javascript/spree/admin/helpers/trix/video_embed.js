import { post, destroy } from '@rails/request.js'

const lang = Trix.config.lang
lang['embed'] = 'Embed'
lang['embedVideo'] = 'Embed a video'

Trix.config.toolbar.getDefaultHTML = function() {
  return `<div class="trix-button-row">
      <span class="trix-button-group trix-button-group--text-tools" data-trix-button-group="text-tools">
        <button type="button" class="trix-button trix-button--icon trix-button--icon-bold" data-trix-attribute="bold" data-trix-key="b" title="${lang.bold}" tabindex="-1">${lang.bold}</button>
        <button type="button" class="trix-button trix-button--icon trix-button--icon-italic" data-trix-attribute="italic" data-trix-key="i" title="${lang.italic}" tabindex="-1">${lang.italic}</button>
        <button type="button" class="trix-button trix-button--icon trix-button--icon-strike" data-trix-attribute="strike" title="${lang.strike}" tabindex="-1">${lang.strike}</button>
        <button type="button" class="trix-button trix-button--icon trix-button--icon-link" data-trix-attribute="href" data-trix-action="link" data-trix-key="k" title="${lang.link}" tabindex="-1">${lang.link}</button>
      </span>

      <span class="trix-button-group trix-button-group--block-tools" data-trix-button-group="block-tools">
        <button type="button" class="trix-button trix-button--icon trix-button--icon-heading-1" data-trix-attribute="heading1" title="${lang.heading1}" tabindex="-1">${lang.heading1}</button>
        <button type="button" class="trix-button trix-button--icon trix-button--icon-quote" data-trix-attribute="quote" title="${lang.quote}" tabindex="-1">${lang.quote}</button>
        <button type="button" class="trix-button trix-button--icon trix-button--icon-code" data-trix-attribute="code" title="${lang.code}" tabindex="-1">${lang.code}</button>
        <button type="button" class="trix-button trix-button--icon trix-button--icon-bullet-list" data-trix-attribute="bullet" title="${lang.bullets}" tabindex="-1">${lang.bullets}</button>
        <button type="button" class="trix-button trix-button--icon trix-button--icon-number-list" data-trix-attribute="number" title="${lang.numbers}" tabindex="-1">${lang.numbers}</button>
        <button type="button" class="trix-button trix-button--icon trix-button--icon-decrease-nesting-level" data-trix-action="decreaseNestingLevel" title="${lang.outdent}" tabindex="-1">${lang.outdent}</button>
        <button type="button" class="trix-button trix-button--icon trix-button--icon-increase-nesting-level" data-trix-action="increaseNestingLevel" title="${lang.indent}" tabindex="-1">${lang.indent}</button>
      </span>

      <span class="trix-button-group trix-button-group--file-tools" data-trix-button-group="file-tools">
        <button type="button" class="trix-button trix-button--icon trix-button--icon-attach" data-trix-action="attachFiles" title="${lang.attachFiles}" tabindex="-1">${lang.attachFiles}</button>
        <button type="button" class="trix-button trix-button--icon trix-button--icon-embed" data-trix-action="x-video-embed" title="${lang.embedVideo}" tabindex="-1">${lang.embedVideo}</button>
      </span>

      <span class="trix-button-group-spacer"></span>

      <span class="trix-button-group trix-button-group--history-tools" data-trix-button-group="history-tools">
        <button type="button" class="trix-button trix-button--icon trix-button--icon-undo" data-trix-action="undo" data-trix-key="z" title="${lang.undo}" tabindex="-1">${lang.undo}</button>
        <button type="button" class="trix-button trix-button--icon trix-button--icon-redo" data-trix-action="redo" data-trix-key="shift+z" title="${lang.redo}" tabindex="-1">${lang.redo}</button>
      </span>
    </div>

    <div class="trix-dialogs" data-trix-dialogs>
      <div class="trix-dialog trix-dialog--link" data-trix-dialog="href" data-trix-dialog-attribute="href">
        <div class="trix-dialog__link-fields">
          <input type="url" name="href" class="trix-input trix-input--dialog" placeholder="${lang.urlPlaceholder}" aria-label="${lang.url}" data-trix-input>
          <div class="trix-button-group">
            <input type="button" class="trix-button trix-button--dialog" value="${lang.link}" data-trix-method="setAttribute">
            <input type="button" class="trix-button trix-button--dialog" value="${lang.unlink}" data-trix-method="removeAttribute">
          </div>
        </div>
      </div>

      <div class="trix-dialog trix-dialog--x-video-embed" data-trix-dialog="href" data-trix-dialog-attribute="href">
        <div class="trix-dialog__link-fields">
          <input type="url" name="href" class="trix-input trix-input--dialog" placeholder="${lang.urlPlaceholder}" aria-label="${lang.url}" data-trix-input>
          <div class="trix-button-group">
            <input type="button" class="trix-button trix-button--dialog" value="${lang.embed}">
          </div>
        </div>

        <div class="trix-dialog--error-container mt-2 d-none">
          <small class="trix-dialog--error-message text-danger"></small>
        </div>
      </div>
    </div>`
}

// Show a dialog for embedding a video after clicking the video embed button
document.addEventListener("trix-action-invoke", function(event) {
  const { invokingElement, actionName } = event

  if (actionName == "x-video-embed") {
    const dialog = invokingElement.closest("trix-toolbar").querySelector(".trix-dialog--x-video-embed")
    const input = dialog.querySelector('.trix-input--dialog')

    if (!invokingElement.classList.contains("trix-active")) {
      activateTrixElement(invokingElement)
      activateTrixElement(dialog)

      input.disabled = false
      input.focus()
    } else {
      input.disabled = true

      deactivateTrixElement(dialog)
      deactivateTrixElement(invokingElement)
    }
  }
})

// Clean up the video embed attachment after removing it from the rich text content
document.addEventListener("trix-attachment-remove", async function(event) {
  const { attachment } = event
  const { sgid } = attachment.attachment.attributes.values

  destroy(`${Spree.adminPath}/action_text/video_embeds/${sgid}`, { responseKind: 'json' })
})

function initializeTrixEditor(editor) {
  // Deactivate video embed button after clicking on the editor window
  editor.addEventListener("click", function(_event) {
    const toolbar = editor.previousElementSibling

    if (toolbar.tagName == "TRIX-TOOLBAR") {
      const videoEmbedButton = toolbar.querySelector('[data-trix-action="x-video-embed"]')

      if (videoEmbedButton && videoEmbedButton.classList.contains("trix-active")) {
        deactivateTrixElement(videoEmbedButton)
      }
    }
  })

  // Attach a video embed
  const toolbar = editor.previousElementSibling

  if (toolbar.tagName == "TRIX-TOOLBAR") {
    const dialog = toolbar.querySelector(".trix-dialog--x-video-embed")
    const embedButton = dialog.querySelector(".trix-button--dialog")

    embedButton.addEventListener("click", async function(event) {
      const input = event.target.closest('.trix-dialog--x-video-embed').querySelector('.trix-input--dialog')

      input.disabled = true
      embedButton.disabled = true

      const errorContainer = dialog.querySelector(".trix-dialog--error-container")
      const errorMessage = errorContainer.querySelector(".trix-dialog--error-message")

      if (!errorContainer.classList.contains('d-none')) {
        errorContainer.classList.add('d-none')
      }

      errorMessage.innerHTML = ''

      const response = await post(`${Spree.adminPath}/action_text/video_embeds`, { body: JSON.stringify({ url: input.value }), responseKind: 'json' })

      if (response.ok) {
        const { sgid, content } = await response.json

        const attachment = new Trix.Attachment({ content, sgid })
        editor.editor.insertAttachment(attachment)

        const videoEmbedButton = toolbar.querySelector('[data-trix-action="x-video-embed"]')
        deactivateTrixElement(videoEmbedButton)

        input.value = ''
        embedButton.disabled = false
      } else {
        const { error } = await response.json

        if (errorContainer.classList.contains('d-none')) {
          errorContainer.classList.remove('d-none')
        }

        errorMessage.innerHTML = error

        input.disabled = false
        embedButton.disabled = false
      }
    })
  }
}

function activateTrixElement(element) {
  element.classList.add("trix-active")
  element.setAttribute("data-trix-active", "")
}

function deactivateTrixElement(element) {
  element.classList.remove("trix-active")
  element.removeAttribute("data-trix-active")
}

// On page reload, trix-initialize event is not fired, so we need to initialize the toolbar and editor here
const toolbars = document.querySelectorAll('trix-toolbar')
toolbars.forEach(toolbar => toolbar.innerHTML = Trix.config.toolbar.getDefaultHTML())

const trixEditors = document.querySelectorAll('trix-editor')
trixEditors.forEach(editor => initializeTrixEditor(editor))

// This will be used to initialize the editor after the page is loaded and the editor is added later, eg. in the page builder
document.addEventListener("trix-initialize", function(event) {
  const editor = event.target
  initializeTrixEditor(editor)
})
