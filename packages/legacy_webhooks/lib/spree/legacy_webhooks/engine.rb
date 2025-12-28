# frozen_string_literal: true

require 'rails/engine'

module Spree
  module LegacyWebhooks
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_legacy_webhooks'

      config.autoload_paths << "#{config.root}/app/models/concerns"

      # Include HasWebhooks concern in configured models
      config.after_initialize do
        # Models that should have legacy webhooks
        webhook_models = [
          'Spree::Address',
          'Spree::Asset',
          'Spree::CreditCard',
          'Spree::CustomerReturn',
          'Spree::InventoryUnit',
          'Spree::LineItem',
          'Spree::OptionType',
          'Spree::OptionValue',
          'Spree::Order',
          'Spree::Payment',
          'Spree::PaymentCaptureEvent',
          'Spree::Price',
          'Spree::Product',
          'Spree::Promotion',
          'Spree::Property',
          'Spree::Prototype',
          'Spree::Refund',
          'Spree::Reimbursement',
          'Spree::ReturnAuthorization',
          'Spree::ReturnItem',
          'Spree::Shipment',
          'Spree::ShippingCategory',
          'Spree::ShippingMethod',
          'Spree::StockItem',
          'Spree::StockLocation',
          'Spree::StockMovement',
          'Spree::StockTransfer',
          'Spree::Store',
          'Spree::StoreCredit',
          'Spree::TaxCategory',
          'Spree::Taxon',
          'Spree::Taxonomy',
          'Spree::TaxRate',
          'Spree::Variant',
          'Spree::WishedItem',
          'Spree::Wishlist',
          'Spree::Zone'
        ]

        webhook_models.each do |model_name|
          model = model_name.safe_constantize
          next unless model

          model.include(Spree::Webhooks::HasWebhooks) unless model.included_modules.include?(Spree::Webhooks::HasWebhooks)
        end

        # Include model-specific webhook concerns
        Spree::Order.include(Spree::Order::Webhooks) if defined?(Spree::Order) && !Spree::Order.included_modules.include?(Spree::Order::Webhooks)
        Spree::Payment.include(Spree::Payment::Webhooks) if defined?(Spree::Payment) && !Spree::Payment.included_modules.include?(Spree::Payment::Webhooks)
        Spree::Product.include(Spree::Product::Webhooks) if defined?(Spree::Product) && !Spree::Product.included_modules.include?(Spree::Product::Webhooks)
        Spree::Variant.include(Spree::Variant::Webhooks) if defined?(Spree::Variant) && !Spree::Variant.included_modules.include?(Spree::Variant::Webhooks)
        Spree::Shipment.include(Spree::Shipment::Webhooks) if defined?(Spree::Shipment) && !Spree::Shipment.included_modules.include?(Spree::Shipment::Webhooks)
        Spree::StockItem.include(Spree::StockItem::Webhooks) if defined?(Spree::StockItem) && !Spree::StockItem.included_modules.include?(Spree::StockItem::Webhooks)
        Spree::StockMovement.include(Spree::StockMovement::Webhooks) if defined?(Spree::StockMovement) && !Spree::StockMovement.included_modules.include?(Spree::StockMovement::Webhooks)
      end

      def self.root
        @root ||= Pathname.new(File.expand_path('../../..', __dir__))
      end
    end
  end
end
