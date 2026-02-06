# frozen_string_literal: true

namespace :spree do
  namespace :prefix_ids do
    desc 'Backfill prefix_id for all existing records'
    task backfill: :environment do
      models = [
        Spree::Address,
        Spree::Adjustment,
        Spree::ApiKey,
        Spree::Asset,
        Spree::Calculator,
        Spree::Country,
        Spree::CouponCode,
        Spree::CreditCard,
        Spree::CustomDomain,
        Spree::CustomerGroup,
        Spree::CustomerReturn,
        Spree::DataFeed,
        Spree::Digital,
        Spree::DigitalLink,
        Spree::Export,
        Spree::GatewayCustomer,
        Spree::GiftCard,
        Spree::GiftCardBatch,
        Spree::Import,
        Spree::ImportMapping,
        Spree::ImportRow,
        Spree::Integration,
        Spree::InventoryUnit,
        Spree::Invitation,
        Spree::LineItem,
        Spree::LogEntry,
        Spree::Metafield,
        Spree::MetafieldDefinition,
        Spree::NewsletterSubscriber,
        Spree::OptionType,
        Spree::OptionValue,
        Spree::Order,
        Spree::Payment,
        Spree::PaymentCaptureEvent,
        Spree::PaymentMethod,
        Spree::PaymentSource,
        Spree::Policy,
        Spree::Post,
        Spree::PostCategory,
        Spree::Price,
        Spree::PriceList,
        Spree::PriceRule,
        Spree::Product,
        Spree::Promotion,
        Spree::PromotionAction,
        Spree::PromotionCategory,
        Spree::PromotionRule,
        Spree::Prototype,
        Spree::Refund,
        Spree::RefundReason,
        Spree::Reimbursement,
        Spree::Reimbursement::Credit,
        Spree::ReimbursementType,
        Spree::Report,
        Spree::ReturnAuthorization,
        Spree::ReturnAuthorizationReason,
        Spree::ReturnItem,
        Spree::Role,
        Spree::Shipment,
        Spree::ShippingCategory,
        Spree::ShippingMethod,
        Spree::ShippingMethodCategory,
        Spree::ShippingRate,
        Spree::State,
        Spree::StateChange,
        Spree::StockItem,
        Spree::StockLocation,
        Spree::StockMovement,
        Spree::StockTransfer,
        Spree::Store,
        Spree::StoreCredit,
        Spree::StoreCreditCategory,
        Spree::StoreCreditEvent,
        Spree::StoreCreditType,
        Spree::StoreProduct,
        Spree::TaxCategory,
        Spree::TaxRate,
        Spree::Taxon,
        Spree::TaxonRule,
        Spree::Taxonomy,
        Spree::UserIdentity,
        Spree::Variant,
        Spree::WebhookDelivery,
        Spree::WebhookEndpoint,
        Spree::WishedItem,
        Spree::Wishlist,
        Spree::Zone
      ]

      # Add user classes if they exist
      models << Spree.user_class if Spree.user_class.present?
      models << Spree.admin_user_class if Spree.admin_user_class.present? && Spree.admin_user_class != Spree.user_class

      models.each do |model|
        next unless model.table_exists?
        next unless model.column_names.include?('prefix_id')
        next unless model.respond_to?(:_prefix_id_prefix) && model._prefix_id_prefix.present?

        puts "Backfilling #{model.name}..."
        count = 0

        model.unscoped.where(prefix_id: nil).find_each do |record|
          record.generate_prefix_id
          record.update_column(:prefix_id, record.prefix_id)
          count += 1
        end

        puts "  Updated #{count} records"
      end

      puts 'Done!'
    end
  end
end
