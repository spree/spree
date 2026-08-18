require 'rails/engine'

module SpreeStripe
  class Engine < Rails::Engine
    isolate_namespace Spree
    engine_name 'spree_stripe'

    config.paths.add 'app/subscribers', eager_load: true

    config.generators do |g|
      g.test_framework :rspec
    end

    # Core assigns the payment method registry in its own after_initialize, so
    # appending has to happen in a later one — engine callbacks run in load order.
    config.after_initialize do
      Rails.application.config.spree.payment_methods << SpreeStripe::Gateway
      Spree.subscribers << SpreeStripe::CustomerUpdatedSubscriber
    end
  end
end
