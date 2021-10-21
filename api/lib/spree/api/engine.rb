require 'rails/engine'

module Spree
  module Api
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_api'

      initializer 'spree.api.environment', before: :load_config_initializers do |_app|
        Spree::Api::Config = Spree::ApiConfiguration.new
        Spree::Api::Dependencies = Spree::ApiDependencies.new
      end

      initializer 'spree.api.checking_migrations' do
        Migrations.new(config, engine_name).check
      end

      initializer 'spree.api.checking_deprecated_preferences' do
        Spree::Api::Config.deprecated_preferences.each do |pref|
          # FIXME: we should only notify about deprecated preferences that are in use, not all of them
          # warn "[DEPRECATION] Spree::Api::Config[:#{pref[:name]}] is deprecated. #{pref[:message]}"
        end
      end

      def self.activate
        [
          Spree::Address, Spree::Asset, Spree::CmsPage, Spree::CreditCard, Spree::CustomerReturn,
          Spree::DigitalLink, Spree::Digital, Spree::InventoryUnit, Spree::LineItem, Spree::MenuItem,
          Spree::Menu, Spree::OptionType, Spree::OptionValue, Spree::Order, Spree::PaymentCaptureEvent,
          Spree::Payment, Spree::Price, Spree::Product, Spree::Promotion, Spree::Property, Spree::Prototype,
          Spree::Refund, Spree::Reimbursement, Spree::ReturnAuthorization, Spree::ReturnItem, Spree::Role,
          Spree::Shipment, Spree::ShippingCategory, Spree::ShippingMethod, Spree::ShippingRate,
          Spree::StockItem, Spree::StockLocation, Spree::StockMovement, Spree::StockTransfer,
          Spree::StoreCredit, Spree::Store, Spree::TaxCategory, Spree::TaxRate, Spree::Taxonomy,
          Spree::Taxon, Spree::Variant, Spree::WishedItem, Spree::Wishlist, Spree::Zone
        ].each do |webhookable_class|
          webhookable_class.include(Spree::Webhooks::HasWebhooks)
        end

        Dir.glob(File.join(File.dirname(__FILE__), '../../../app/models/spree/api/webhooks/*_decorator*.rb')) do |c|
          Rails.application.config.cache_classes ? require(c) : load(c)
        end
      end

      def self.root
        @root ||= Pathname.new(File.expand_path('../../..', __dir__))
      end

      config.to_prepare &method(:activate).to_proc
    end
  end
end
