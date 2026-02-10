import Sortable from "stimulus-sortable"

export default class extends Sortable {
  async onUpdate({ item, newIndex }) {
    const form = item.closest('form')
    if (form) {
      form.requestSubmit()
    }
  }
}