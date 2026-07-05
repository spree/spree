import { Controller } from '@hotwired/stimulus'
export default class extends Controller {
  static targets = [
    'form',
    'fontForm',
    'previewContainer',
    'iframe',
    'sidebar',
    'sidebarIcon',
    'desktopButton',
    'mobileButton'
  ]

  static values = {
    previewUrl: String
  }

  connect() {
    this.resizeObserver = new ResizeObserver(() => {
      this.removeOverlays()
      this.initializeOverlays()
    })
    this.setResponsiveBreakpoint()
  }

  disconnect() {
    this.resizeObserver.disconnect()
  }

  initialize() {
    this.loadPreview()
  }

  loadPreview() {
    if (this.previewUrlValue) {
      this.iframeTarget.src = this.previewUrlValue
    }
  }

  initializeVisualEditor() {
    this.iframeDocument = this.iframeTarget.contentDocument
    this.iframeWindow = this.iframeTarget.contentWindow

    this.iframeDocument.addEventListener('turbo:frame-render', (event) => {
      const url = new URL(event.detail.fetchResponse.response.url)
      const activeOverlayId = url.searchParams.get('editor_id')

      this.resizeObserver.observe(this.iframeDocument.body)

      this.removeOverlays()
      this.initializeOverlays(activeOverlayId)
    })

    this.iframeDocument.addEventListener('turbo:load', (event) => {
      const url = new URL(event.detail.url)
      const activeOverlayId = url.searchParams.get('editor_id')

      this.resizeObserver.observe(this.iframeDocument.body)

      this.removeOverlays()
      this.initializeOverlays(activeOverlayId)
    })

    this.resizeObserver.observe(this.iframeDocument.body)

    this.removeOverlays()
    this.initializeOverlays()
  }

  removeOverlays() {
    const overlays = this.iframeDocument.querySelectorAll('.editor-overlay')
    overlays.forEach((el) => el.remove())
  }

  initializeOverlays(activeOverlayId = null) {
    const elements = this.iframeDocument.querySelectorAll('[data-editor-id]')
    elements.forEach((el) => this.initializeOverlay(el, activeOverlayId === el.dataset.editorId))
  }

  showSectionsSidebar() {
    const button = document.getElementById('show-sections-sidebar')
    if (button) {
      button.click()
      button.classList.remove('active')
    }
  }

  initializeOverlay(el, isActive = false) {
    const overlay = this.iframeDocument.createElement('div')
    const id = el.dataset.editorId
    const parentId = el.dataset.editorParentId || null // this is only present for blocks, not sections
    const link = el.dataset.editorLink
    overlay.classList.add('editor-overlay')
    overlay.dataset.editorId = id

    if (parentId) {
      const parent = this.iframeDocument.querySelector(`[data-editor-id="${parentId}"]`)
      if (parent) {
        parent.parentNode.appendChild(overlay)
      }
    } else {
      el.parentNode.appendChild(overlay)
    }
    let zIndex = 1088 // sections have 1088, blocks have 1089, links have 1090

    switch (true) {
      case id.startsWith('block'):
        zIndex = 1089
        break
      case id.startsWith('link'):
        zIndex = 1090
        break
    }

    overlay.style.zIndex = zIndex

    const { left, top } = el.getBoundingClientRect()
    overlay.style.position = 'absolute'
    overlay.style.top = `${top + this.iframeWindow.scrollY}px`
    overlay.style.left = `${left + this.iframeWindow.scrollX}px`
    overlay.style.width = `${el.offsetWidth}px`
    overlay.style.height = `${el.offsetHeight}px`

    overlay.addEventListener('click', (_event) => {
      this.clearActiveOverlays()
      this.iframeWindow.makeOverlayActive(id)
      window.top.document.getElementById('page_sidebar').src = link
      this.showSectionsSidebar()
    })

    const editorToolbar = document.getElementById('editor-toolbar-' + id)
    if (editorToolbar) {
      const overlayToolbar = this.iframeDocument.createElement('div')
      overlayToolbar.classList.add('editor-overlay-toolbar')
      overlayToolbar.innerHTML = editorToolbar.innerHTML
      overlay.appendChild(overlayToolbar)

      const toolbarHigher = overlayToolbar.querySelector(
        '.editor-toolbar-higher'
      )
      const toolbarLower = overlayToolbar.querySelector('.editor-toolbar-lower')
      const toolbarEdit = overlayToolbar.querySelector('.editor-toolbar-edit')
      const toolbarDelete = overlayToolbar.querySelector(
        '.editor-toolbar-delete'
      )

      if (toolbarHigher) {
        toolbarHigher.addEventListener('click', (event) => {
          event.stopPropagation()
          const moveButton = document.getElementById(
            'editor-toolbar-higher-' + id
          )
          if (moveButton) moveButton.click()

          // this is only needed for sections, not blocks
          if (!parentId) {
            const turboFrame = el.parentNode
            if (turboFrame) {
              turboFrame.previousSibling.before(turboFrame)
              this.iframeWindow.scrollToOverlay(overlay)
            }
          } else {
            el.parentNode.insertBefore(el, el.previousSibling)
          }
          this.removeOverlays()
          this.initializeOverlays()
        })
      }
      if (toolbarLower) {
        toolbarLower.addEventListener('click', (event) => {
          event.stopPropagation()
          const moveButton = document.getElementById(
            'editor-toolbar-lower-' + id
          )
          if (moveButton) moveButton.click()

          // this is only needed for sections, not blocks
          if (!parentId) {
            const turboFrame = el.parentNode
            if (turboFrame) {
              turboFrame.nextSibling.after(turboFrame)
              this.iframeWindow.scrollToOverlay(overlay)
            }
          } else {
            el.parentNode.insertBefore(el.nextSibling, el)
          }
          this.removeOverlays()
          this.initializeOverlays()
        })
      }
      if (toolbarEdit) {
        toolbarEdit.addEventListener('click', (event) => {
          event.stopPropagation()
          this.clearActiveOverlays()
          this.iframeWindow.makeOverlayActive(id)
          window.top.document.getElementById('page_sidebar').src = link
          this.showSectionsSidebar()
          this.showSidebarMobile()
        })
      }
      if (toolbarDelete) {
        toolbarDelete.addEventListener('click', (event) => {
          event.stopPropagation()
          const deleteButton = document.getElementById(
            'editor-toolbar-delete-' + id
          )
          if (deleteButton) deleteButton.click()
        })
      }

      if (isActive) this.iframeWindow.makeOverlayActive(id)
    }

    overlay.addEventListener('mouseenter', (_event) => {
      const sidebarElement = document.querySelector(
        '[data-page-builder-editor-id-param="' + id + '"]'
      )
      if (sidebarElement) sidebarElement.classList.add('hover')
    })
    overlay.addEventListener('mouseout', (_event) => {
      const sidebarElement = document.querySelector(
        '[data-page-builder-editor-id-param="' + id + '"]'
      )
      if (sidebarElement) sidebarElement.classList.remove('hover')
    })
  }

  clearActiveOverlays(event) {
    if (event?.currentTarget?.classList.contains('back')) {
      this.hideSidebarMobile()
    }

    this.iframeDocument
      .querySelectorAll('.editor-overlay')
      .forEach((overlayEl) => {
        overlayEl.classList.remove('editor-overlay-active')
        overlayEl.classList.remove('editor-overlay-hover')
      })
  }

  makeOverlayActive(event) {
    this.showSectionsSidebar() // making sure the page sidebar is open
    const editorId = event.params.editorId
    this.clearActiveOverlays()
    this.iframeWindow.makeOverlayActive(editorId)
  }

  toggleHighlightElement(event) {
    const editorId = event.params.editorId
    if (this.iframeWindow) this.iframeWindow.toggleHighlightElement(editorId)
  }

  refreshPreview(_event) {
    // save the preview and re-render iframe
    this.formTarget.requestSubmit()
  }

  refreshFontPreview(_event) {
    // save the preview and re-render iframe
    this.fontFormTarget.requestSubmit()
  }

  setResponsiveBreakpoint(event) {
    event?.preventDefault()

    const view = event ? event?.params.breakpoint : sessionStorage.getItem('breakpoint');

    if (view === 'desktop') {
      sessionStorage.setItem('breakpoint', 'desktop');

      this.previewContainerTarget.classList.remove('mobileLiveView')
      this.previewContainerTarget.classList.add('desktopLiveView')
      this.desktopButtonTarget.classList.add('active')
      this.mobileButtonTarget.classList.remove('active')
    } else {
      sessionStorage.setItem('breakpoint', 'mobile');

      this.previewContainerTarget.classList.remove('desktopLiveView')
      this.previewContainerTarget.classList.add('mobileLiveView')
      this.desktopButtonTarget.classList.remove('active')
      this.mobileButtonTarget.classList.add('active')
    }
  }

  addSection(event) {
    event.stopPropagation()

    this.showSectionsSidebar()

    window.top.document.getElementById(
      'page_sidebar'
    ).src = `${window.top.location.origin}/admin/page_previews/id/sections/new`

    this.showSidebarMobile()
  }

  showSidebarMobile(event) {
    if (event?.currentTarget?.classList.contains('from-hamburger')) {
      ;[...event.currentTarget.parentNode.children].forEach((el) => {
        if (event.currentTarget !== el) el.classList.remove('active')
      })
      document.querySelector('.mobile-hamburger').click()
    }

    document.body.classList.add('mobile_sidebar_open')
  }

  hideSidebarMobile() {
    document.body.classList.remove('mobile_sidebar_open')
  }

  deleteCallback() {
    this.removeOverlays()
    this.initializeOverlays()
  }
}
