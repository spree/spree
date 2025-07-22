import { Controller } from '@hotwired/stimulus'
import { FetchRequest } from '@rails/request.js'

// This controller is needed if you have many forms that are using turbo and can be submitted in rapid succession.
// Turbo by default will cancel all the previous requests and only submit the last one,
// but server side you will still receive all the requests and process them.
// And since the request was cancelled, turbo will not process the response.
// So this may lead to desync between the UI and the server.
// GH issue: https://github.com/hotwired/turbo-rails/issues/310
// Code that causes issue: https://github.com/hotwired/turbo/blob/main/src/core/drive/navigator.js#L32
export default class extends Controller {
  connect() {
    this.element.addEventListener('submit', this.handleSubmit)
    this.submitElements = this.element.querySelectorAll('[type="submit"]')
  }

  disconnect() {
    this.element.removeEventListener('submit', this.handleSubmit)
  }

  handleSubmit = async (event) => {
    event.preventDefault()

    const form = event.target
    const url = form.action
    const method = form.method
    const body = new FormData(form)
    const headers = {}

    const request = new FetchRequest(method, url, {
      body: body,
      headers: headers,
      responseKind: 'turbo-stream'
    })

    this.submitElements.forEach((element) => {
      element.disabled = true
    })
    form.ariaBusy = true

    await request.perform()

    const submitEndEvent = new Event('turbo-stream-form:submit-end')

    this.submitElements.forEach((element) => {
      element.disabled = false
      element.dispatchEvent(submitEndEvent)
    })
    form.ariaBusy = false
  }
}
