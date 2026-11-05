require 'rails/engine'

module SpreeKlaviyo
  class Engine < Rails::Engine
    engine_name 'spree_klaviyo'

    config.after_initialize do
      Spree.integrations << 'Spree::Integrations::Klaviyo'
    end
  end
end
