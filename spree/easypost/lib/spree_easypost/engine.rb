require 'rails/engine'

module SpreeEasyPost
  class Engine < Rails::Engine
    engine_name 'spree_easypost'

    # Gem name and module disagree on word boundaries (spree_easypost →
    # SpreeEasyPost, matching the official EasyPost SDK's casing), so
    # Zeitwerk needs telling once.
    initializer 'spree_easypost.inflections', before: :set_autoload_paths do
      Rails.autoloaders.each do |autoloader|
        autoloader.inflector.inflect('spree_easypost' => 'SpreeEasyPost')
      end
    end

    config.after_initialize do
      Spree.integrations << 'SpreeEasyPost::Integration'
      Spree.delivery_rate_providers << SpreeEasyPost::DeliveryRateProvider
    end
  end
end
