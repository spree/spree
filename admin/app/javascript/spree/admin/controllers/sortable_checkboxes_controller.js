import Sortable from "stimulus-sortable"

export default class extends Sortable {
  async onUpdate({ item, newIndex }) {
    this.closest('form').requestSubmit()
  }
}