import { Controller } from '@hotwired/stimulus'
import { destroy } from '@rails/request.js'

export default class extends Controller {
  static targets = ['checkbox', 'deleteButton']

  static values = {
    deleteUrl: String
  }

  deleteSelected = async (e) => {
    const idsToDelete = this.checkboxTargets.filter((el) => el.checked).map((el) => el.value)

    if (idsToDelete.length && window.confirm('Are you sure?')) {
      this.deleteButtonTarget.disabled = true

      const response = await destroy(this.deleteUrlValue, {
        body: {
          ids: idsToDelete
        },
        responseKind: 'turbo-stream'
      })

      if (response.ok) {
        this.deleteButtonTarget.disabled = false
        this.deleteButtonTarget.classList.add('d-none')
      }
    }
  }

  showDeleteButton = () => {
    if (this.checkboxTargets.some((el) => el.checked)) {
      this.deleteButtonTarget.classList.remove('d-none')
    } else {
      this.deleteButtonTarget.classList.add('d-none')
    }
  }
}
