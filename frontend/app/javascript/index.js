import { Application } from "stimulus"
import * as Controllers from './controllers'
import '@spree/storefront-api-v2-sdk/dist/client'

const application = Application.start()
application.register('coupon-code', Controllers.CouponCodeController)

export default {
  start() {
    console.log('Spree Frontend initialized')
  }
}

