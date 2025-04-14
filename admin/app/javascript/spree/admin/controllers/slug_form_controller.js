import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'name',
    'url',
  ]

  async updateUrlFromName() {
    const name = this.nameTarget.value
    const url = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)+/g, '')
    this.urlTarget.value = url

    if (url && url.length > 0) {
      await this.checkIfSlugIsTaken(url)
    }
  }

  async checkIfSlugIsTaken(url) {
    try {
      const response = await fetch(`/api/v2/storefront/products?slug=${encodeURIComponent(url)}`)
      const data = await response.json()

      if (data && data.length > 0) {
        const randomSuffix = Math.floor(Math.random() * 1000000)
        this.urlTarget.value = `${url}-${randomSuffix}`
      }
    } catch (error) {
      // In case of error we assume the slug is not taken otherwise backend validation will work
      console.error('Error checking if slug is taken', error)
    }
  }
}
