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
    this.panelTarget.classList.add('animate-fade-out-down')
    this.panelTarget.classList.add('hidden')
  }

  togglePanel() {
    if (this.checked.length > 0) {
      this.panelTarget.classList.remove('animate-fade-out-down')
      this.panelTarget.classList.remove('hidden', 'd-none')
      if (this.counterTarget) {
        this.counterTarget.textContent = this.checked.length
      }
    } else {
      this.hidePanel()
    }
  }

  removeRowBackground() {
    this.element.querySelectorAll('tr').forEach((row) => {
      row.classList.remove('active')
    })
  }

  toggleRowBackground() {
    this.element.querySelectorAll('tr').forEach((row) => {
      row.classList.remove('active')
    })
    this.element.querySelectorAll('.row.active').forEach((row) => {
      row.classList.remove('active')
    })
    this.checked.forEach((checkbox) => {
      if (checkbox.closest('tr')) checkbox.closest('tr').classList.add('active')
      else if (checkbox.closest('.row')) checkbox.closest('.row').classList.add('active')
    })
  }

  setBulkAction(e) {
    this.formTarget.action = e.target.dataset.url
    if (e.target.dataset.method) {
      const method = e.target.dataset.method.toLowerCase()
      // HTML forms only support GET and POST, so use hidden _method field for others
      if (method === 'get' || method === 'post') {
        this.formTarget.method = method
        this.removeMethodInput()
      } else {
        this.formTarget.method = 'post'
        this.setMethodInput(method)
      }
    }
  }

  setMethodInput(method) {
    let methodInput = this.formTarget.querySelector('input[name="_method"]')
    if (!methodInput) {
      methodInput = document.createElement('input')
      methodInput.type = 'hidden'
      methodInput.name = '_method'
      this.formTarget.appendChild(methodInput)
    }
    methodInput.value = method
  }

  removeMethodInput() {
    const methodInput = this.formTarget.querySelector('input[name="_method"]')
    if (methodInput) {
      methodInput.remove()
    }
  }
}
