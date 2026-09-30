require 'rails/engine'

module SpreeStripe
  class Engine < Rails::Engine
    isolate_namespace Spree
    engine_name 'spree_stripe'

    config.paths.add 'app/subscribers', eager_load: true

    config.generators do |g|
      g.test_framework :rspec
    end

    config.after_initialize do
      Rails.application.config.spree.payment_methods << SpreeStripe::Gateway
      Spree.subscribers << SpreeStripe::CustomerUpdatedSubscriber
      Spree.payout_providers << SpreeStripe::PayoutProvider
    end
  end
end
