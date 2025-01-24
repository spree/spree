import CheckboxSelectAll from 'stimulus-checkbox-select-all'

export default class extends CheckboxSelectAll {
  static targets = ['panel', 'form', 'counter']

  connect() {
    super.connect()
    this.togglePanel()
    this.toggleRowBackground()
  }

  toggle(e) {
    super.toggle(e)
    this.togglePanel()
    this.toggleRowBackground()
  }

  refresh() {
    super.refresh()
    this.togglePanel()
    this.toggleRowBackground()
  }

  cancel(e) {
    e.preventDefault()
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false
    })
    this.checkboxAllTargets.forEach((checkbox) => {
      checkbox.checked = false
    })
    this.hidePanel()
    this.removeRowBackground()
  }

  hidePanel() {
    this.panelTarget.classList.add('animate__fadeOutDown')
    this.panelTarget.classList.add('d-none')
  }

  togglePanel() {
    if (this.checked.length > 0) {
      this.panelTarget.classList.remove('animate__fadeOutDown')
      this.panelTarget.classList.remove('d-none')
      if (this.counterTarget) {
        this.counterTarget.textContent = this.checked.length
      }
    } else {
      this.hidePanel()
    }
  }

  removeRowBackground() {
    this.element.querySelectorAll('tr').forEach((row) => {
      row.classList.remove('bg-active')
    })
  }

  toggleRowBackground() {
    this.element.querySelectorAll('tr').forEach((row) => {
      row.classList.remove('bg-active')
    })
    this.element.querySelectorAll('.row.bg-active').forEach((row) => {
      row.classList.remove('bg-active')
    })
    this.checked.forEach((checkbox) => {
      if (checkbox.closest('tr')) checkbox.closest('tr').classList.add('bg-active')
      else if (checkbox.closest('.row')) checkbox.closest('.row').classList.add('bg-active')
    })
  }

  setBulkAction(e) {
    this.formTarget.action = e.target.dataset.url
    if (e.target.dataset.method) {
      this.formTarget.method = e.target.dataset.method
    }
  }
}
