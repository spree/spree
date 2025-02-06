import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['featuredImageContainer', 'colorsContainer', 'priceContainer', 'link', 'addToWishlist']
  connect() {
    this.canPreview = false
    this.resetSelectedValues()
    if (this.hasColorsContainerTarget && this.hasFeaturedImageContainerTarget) {
      this.saveOriginalPreview()
      this.setFeaturedImageHeight() // Set the height of the featured image container to prevent layout shift
      this.colorsContainerTarget.addEventListener('mouseleave', this.restoreOriginalPreview)
    }
  }

  disconnect() {
    this.canPreview = false
    this.resetSelectedValues()
    if (this.hasColorsContainerTarget && this.hasFeaturedImageContainerTarget) {
      this.restoreOriginalPreview()
      this.colorsContainerTarget.removeEventListener('mouseleave', this.restoreOriginalPreview)
    }
  }

  resetSelectedValues() {
    this.selectedVariantFeaturedImageHTML = null
    this.selectedVariantPriceHTML = null
    this.selectedAddToWishlistHTML = null
  }

  showMoreColors(e) {
    e.preventDefault()

    const colors = [...this.colorsContainerTarget.children]
    colors.forEach((child) => {
      child.style.display = 'flex'
    })

    e.target.style.display = 'none'
  }

  redirectToVariant(e) {
    const el = e.target.closest('[data-variant-id]')
    const url = new URL(this.linkTarget.href)
    url.searchParams.set('variant_id', el.dataset.variantId)
    Turbo.visit(url)
  }

  handlePreview(e) {
    if (window.matchMedia('(pointer: coarse)').matches) return

    this.preview(e.target)
  }

  preview(target) {
    if (!this.canPreview) return

    const featuredImageTemplate = target.querySelector('template[data-featured-image-template]')

    if (featuredImageTemplate) {
      this.setFeaturedImageHTML(featuredImageTemplate.innerHTML)
    } else {
      this.restoreOriginalImage()
    }

    const priceTemplate = target.querySelector('template[data-price-template]')
    if (priceTemplate) {
      this.setPriceHTML(priceTemplate.innerHTML)
    } else {
      this.restoreOriginalPrice()
    }

    const addToWishlistTemplate = target.querySelector('template[data-add-to-wishlist-template]')
    if (addToWishlistTemplate) {
      this.setAddToWishlistHTML(addToWishlistTemplate.innerHTML)
    } else {
      this.restoreOriginalAddToWishlist()
    }
  }

  saveOriginalPreview() {
    this.originalFeaturedImageHTML = this.featuredImageContainerTarget.innerHTML
    this.originalPriceHTML = this.priceContainerTarget.innerHTML
    this.originalAddToWishlistHTML = this.addToWishlistTarget.innerHTML
  }

  restoreOriginalPreview = () => {
    if (this.selectedVariantFeaturedImageHTML) {
      this.setFeaturedImageHTML(this.selectedVariantFeaturedImageHTML)
    } else {
      this.restoreOriginalImage()
    }
    if (this.selectedVariantPriceHTML) {
      this.setPriceHTML(this.selectedVariantPriceHTML)
    } else {
      this.restoreOriginalPrice()
    }
    if (this.selectedAddToWishlistHTML) {
      this.setAddToWishlistHTML(this.selectedAddToWishlistHTML)
    } else {
      this.restoreOriginalAddToWishlist()
    }
  }

  restoreOriginalImage() {
    this.setFeaturedImageHTML(this.originalFeaturedImageHTML)
  }

  restoreOriginalPrice() {
    this.setPriceHTML(this.originalPriceHTML)
  }

  restoreOriginalAddToWishlist() {
    this.setAddToWishlistHTML(this.originalAddToWishlistHTML)
  }

  setPriceHTML(html) {
    if (this.priceContainerTarget.innerHTML !== html) {
      this.priceContainerTarget.innerHTML = html
    }
  }

  setFeaturedImageHTML(html) {
    if (this.featuredImageContainerTarget.innerHTML !== html) {
      this.featuredImageContainerTarget.innerHTML = html
    }
  }

  setAddToWishlistHTML(html) {
    if (this.addToWishlistTarget.innerHTML !== html) {
      this.addToWishlistTarget.innerHTML = html
    }
  }

  setFeaturedImageHeight() {
    const featuredImage = this.featuredImageContainerTarget.querySelector('img')
    if (featuredImage) {
      if (featuredImage.complete) {
        this.featuredImageContainerTarget.style.height = `${this.featuredImageContainerTarget.offsetHeight}px`
        this.canPreview = true
      } else {
        featuredImage.onload = () => {
          this.featuredImageContainerTarget.style.height = `${this.featuredImageContainerTarget.offsetHeight}px`
          // Disable preview if the image is not loaded - this prevents layout shift
          this.canPreview = true
        }
      }
    } else {
      this.canPreview = true
    }
  }
}
