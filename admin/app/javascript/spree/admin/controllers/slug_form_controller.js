import { Controller } from '@hotwired/stimulus'
import debounce from 'spree/core/helpers/debounce'

export default class extends Controller {
  static targets = [
    'name',
    'url',
  ]

  connect() {
    this.updateUrlFromName = debounce(this.updateUrlFromName.bind(this), 300)
  }

  async updateUrlFromName() {
    const currentName = this.nameTarget?.getAttribute('value');
    const currentUrl = this.urlTarget?.getAttribute('value');
    const name = this.nameTarget.value;
    const url = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)+/g, '');
    const isNameChanged = currentName !== name.trim(); // This flag checks if name was restored to original value
    const isUrlChanged = currentUrl !== url; // This flag checks if token was copied from url to name

    this.urlTarget.value = isNameChanged && isUrlChanged ? url : currentUrl;

    if (url && url.length > 0 && isNameChanged && isUrlChanged) {
      await this.checkIfSlugIsTaken(url);
    }
    this.dispatch('slugFinalized');
  }

  async checkIfSlugIsTaken(url) {
    try {
      const response = await fetch(`/api/v2/storefront/products?filter[slug]=${encodeURIComponent(url)}`);
      console.log(Math.random())

      const { data } = await response.json();

      if (data && data.length > 0) {
        const randomSuffix = this.uuidv4();
        this.urlTarget.value = `${url}-${randomSuffix}`;
      }
    } catch (error) {
      // In case of error we assume the slug is not taken, otherwise backend validation will work
      console.error('Error checking if slug is taken', error);
    }
  }

  uuidv4() {
    return "10000000-1000-4000-8000-100000000000".replace(/[018]/g, c =>
      (+c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> +c / 4).toString(16)
    );
  }
}
