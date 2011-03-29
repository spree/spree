class Activator < ActiveRecord::Base

  EVENT_NAMES = [
    'spree.cart.add',
    'spree.checkout.coupon_code_added',
    'spree.order.contents_changed',
    'spree.user.signup'
  ]

  scope :event_name_starts_with, lambda{|name| where('event_name like ?', "#{name}%") }
  scope :active, where('( starts_at IS NULL OR starts_at < ? ) AND ( expires_at IS NULL OR expires_at > ?)', Time.now, Time.now)

  def activate(payload)
  end

  def expired?
    starts_at && Time.now < starts_at ||
    expires_at && Time.now > expires_at
  end

end
