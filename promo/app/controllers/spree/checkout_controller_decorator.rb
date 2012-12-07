Spree::CheckoutController.class_eval do
  self.update_hooks.add(:apply_coupon_code)
end
