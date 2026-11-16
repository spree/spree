require 'rails/engine'

module SpreeAdyen
  class Engine < Rails::Engine
    isolate_namespace Spree
    engine_name 'spree_adyen'

    # Core assigns the payment method registry in its own after_initialize, so
    # appending has to happen in a later one — engine callbacks run in load order.
    config.after_initialize do
      Rails.application.config.spree.payment_methods << SpreeAdyen::Gateway
    end
  end
end
