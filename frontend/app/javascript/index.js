import { Application } from 'stimulus'
import { definitionsFromContext } from "stimulus/webpack-helpers"
const controllersContext = require.context('./controllers', true, /_controller\.js$/)

const application = Application.start()

application.load(definitionsFromContext(controllersContext))

export default {
  start() {
    console.log('Spree Frontend initialized')
  }
}

