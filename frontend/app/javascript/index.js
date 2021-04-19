import { Application } from "stimulus"

const application = Application.start()
application.register('coupon-code', Controllers.CouponCodeController)

export default {
  start() {
    console.log('Spree Frontend initialized')
  }
}

