import { Application } from "stimulus"
import * as Controllers from './controllers'

const application = Application.start()
application.register('coupon-code', Controllers.CouponCodeController)

export default {
  start() {
    console.log('Spree Frontend initialized')
  }
}

