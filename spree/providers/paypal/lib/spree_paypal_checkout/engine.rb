require 'rails/engine'

module SpreePaypalCheckout
  class Engine < Rails::Engine
    isolate_namespace Spree
    engine_name 'spree_paypal_checkout'

    # Core assigns the payment method registry in its own after_initialize, so
    # appending has to happen in a later one — engine callbacks run in load order.
    config.after_initialize do
      Rails.application.config.spree.payment_methods << SpreePaypalCheckout::Gateway
    end
  end
end
