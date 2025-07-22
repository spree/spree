import { Controller } from "@hotwired/stimulus"
import { Sortable } from "sortablejs"
import { put } from '@rails/request.js'

export default class extends Controller {
  static values = { handle: String }

  connect() {
    const itemSortable = {
      ...this.options
    }

    let containers = null
    containers = this.element.querySelectorAll("[data-sortable-tree-parent-id-value]")

    for (let i = 0; i < containers.length; i++) {
      new Sortable(containers[i], itemSortable)
    }
  }

  async end({ item, newIndex, to }) {
    if (!item.dataset.sortableTreeUpdateUrlValue) return

    const data = {
      [item.dataset.sortableTreeResourceNameValue]: {
        new_parent_id: to.dataset.sortableTreeParentIdValue,
        new_position_idx: newIndex
      }
    }

    const response = await put(item.dataset.sortableTreeUpdateUrlValue, { body: data, responseKind: 'json' })

    if (!response.ok) {
      alert("This move could not be saved.")
    }
  }

  get options() {
    return {
      group: {
        name: "sortable-tree",
        pull: true,
        put: true
      },
      handle: this.handleValue || undefined,
      swapThreshold: 0.5,
      emptyInsertThreshold: 8,
      dragClass: "item-dragged",
      draggable: ".draggable",
      animation: 350,
      forceFallback: false,
      onEnd: this.end
    }
  }
}
