%w(
  spree_core
  spree_payment_gateway
  spree_api
  spree_dashboard
  spree_promotions
).each do |extension|
  require "#{extension}/engine"
end

Spree::ThemeSupport::HookListener.subclasses.each do |hook_class|
  Spree::ThemeSupport::Hook.add_listener(hook_class)
end
