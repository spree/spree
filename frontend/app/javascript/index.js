import { Application } from 'stimulus'
import * as Turbo from '@hotwired/turbo'
import Rails from '@rails/ujs'
import { definitionsFromContext } from 'stimulus/webpack-helpers'
import 'bootstrap/js/dist/util'
import 'bootstrap/js/dist/alert'
import 'bootstrap/js/dist/carousel'
import 'bootstrap/js/dist/collapse'
import 'bootstrap/js/dist/dropdown'
import lazySizes from 'lazysizes'
import Autosave from 'stimulus-rails-autosave'

window.Turbo = Turbo
window.Rails = Rails

const controllersContext = require.context('./controllers', true, /_controller\.js$/)
const spreeStimulusApplication = Application.start()
spreeStimulusApplication.load(definitionsFromContext(controllersContext))
spreeStimulusApplication.register('autosave', Autosave)

const initLazysizes = () => {
  lazySizes.cfg.loadMode = 1
  lazySizes.cfg.loadHidden = false
}

export {
  Spree,
  spreeStimulusApplication,
  initLazysizes
}

export default {
  start() {
    Rails.start()
    initLazysizes()
  }
}

