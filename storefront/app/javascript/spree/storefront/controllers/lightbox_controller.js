import { Controller } from '@hotwired/stimulus'
import PhotoSwipeLightbox from 'photoswipe/lightbox'

const closeSVG = `
<svg class="pswp__icn" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <path d="M3.00029 3L21 20.9688M3 21L20.9997 3.03115" stroke="black" stroke-width="1.5"/>
</svg>`
const arrowPrevSVG = `
<svg class="pswp__icn" width="24" height="24" viewBox="0 0 32 32" fill="none">
  <path d="M2 16H30M2 16L16 2M2 16L16 30" stroke="black" stroke-width="1.5"/>
</svg>`
const arrowNextSVG = `
<svg class="pswp__icn" width="24" height="24" viewBox="0 0 32 32" fill="none">
  <path d="M30 16H2M30 16L16 2M30 16L16 30" stroke="black" stroke-width="1.5"/>
</svg>`

function isTouchDevice() {
  return 'ontouchstart' in window || navigator.maxTouchPoints > 0 || navigator.msMaxTouchPoints > 0
}
export default class extends Controller {
  connect() {
    this.addPhotoSwipeStyles()

    const lightbox = new PhotoSwipeLightbox({
      gallery: this.element,
      children: 'a',
      bgOpacity: 1.0,
      initialZoomLevel: 'fit',
      secondaryZoomLevel: 1,
      pswpModule: () => import('photoswipe'),
      closeSVG,
      arrowPrevSVG,
      arrowNextSVG,
      arrowPrev: true,
      arrowNext: true,
      preload: [1, 4] // https://photoswipe.com/options/#preload
    })

    lightbox.on('firstUpdate', () => {
      if (isTouchDevice() && this.pinchToZoomEl) {
        this.pinchToZoomEl.style.display = 'flex'
      }
    })

    lightbox.on('pointerUp', () => {
      if (this.pinchToZoomEl) this.pinchToZoomEl.style.display = 'none'
    })

    lightbox.on('uiRegister', function () {
      lightbox.pswp.ui.registerElement({
        name: 'bulletsIndicator',
        className: 'pswp__bullets-indicator',
        appendTo: 'wrapper',
        onInit: (el, pswp) => {
          const bullets = []
          let bullet
          let prevIndex = -1
          const itemsCount = pswp.getNumItems()

          if (itemsCount <= 1) {
            return
          }

          for (let i = 0; i < itemsCount; i++) {
            bullet = document.createElement('div')
            bullet.className = 'pswp__bullet'
            bullet.onclick = (e) => {
              pswp.goTo(bullets.indexOf(e.target))
            }
            el.appendChild(bullet)
            bullets.push(bullet)
          }

          pswp.on('change', () => {
            if (prevIndex >= 0) {
              bullets[prevIndex].classList.remove('pswp__bullet--active')
            }
            bullets[pswp.currIndex].classList.add('pswp__bullet--active')
            prevIndex = pswp.currIndex
          })
        }
      })

      lightbox.pswp.ui.registerElement({
        name: 'pagination',
        className: 'pswp__pagination',
        appendTo: 'wrapper',
        onInit: (el, pswp) => {
          const itemsCount = pswp.getNumItems()

          if (itemsCount <= 1) {
            return
          }

          const currentEl = document.createElement('span')
          currentEl.className = 'pswp__pagination--current'
          currentEl.innerHTML = String(pswp.currIndex + 1).padStart(2, '0')

          const allEl = document.createElement('span')
          allEl.className = 'pswp__pagination--all'
          allEl.innerHTML = String(itemsCount).padStart(2, '0')

          el.appendChild(currentEl)
          el.appendChild(document.createTextNode('/'))
          el.appendChild(allEl)

          pswp.on('change', () => {
            currentEl.innerHTML = String(pswp.currIndex + 1).padStart(2, '0')
          })
        }
      })
    })

    lightbox.init()
  }

  get pinchToZoomEl() {
    let pinchToZoom = document.querySelector('#pinch-to-zoom')
    if (this.element.getRootNode() instanceof ShadowRoot) {
      pinchToZoom = this.element.getRootNode().querySelector('#pinch-to-zoom')
    }

    return pinchToZoom
  }

  addPhotoSwipeStyles() {
    if (document.getElementById('photoswipe-styles')) {
      return
    }

    const link = document.createElement('link')
    link.id = 'photoswipe-styles'
    link.rel = 'stylesheet'
    link.href = 'https://esm.sh/photoswipe@5.4.4/dist/photoswipe.css'
    link.onerror = () => console.error('Failed to load PhotoSwipe CSS')
    document.head.appendChild(link)
  }
}
