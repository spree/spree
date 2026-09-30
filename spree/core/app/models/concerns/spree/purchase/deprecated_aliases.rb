module Spree
  module Purchase
    # One-release bridges for the names renamed in 6.0, shared by
    # {Spree::Cart} and {Spree::Order}. Before 6.0 a cart was an incomplete
    # order, so extensions written against 5.x (payment gateways, checkout
    # plugins) call the legacy names on carts too. Every legacy name warns and
    # forwards to its replacement. Removed in 6.1.
    #
    # Renamed columns are also registered with +alias_attribute+, so the legacy
    # name keeps working in +where+ / +find_by+ (those paths do not warn).
    module DeprecatedAliases
      extend ActiveSupport::Concern

      RENAMED_ATTRIBUTES = {
        promo_total: :discount_total,
        item_count: :total_quantity,
        shipment_total: :delivery_total,
        ship_total: :delivery_total,
        special_instructions: :customer_note
      }.freeze

      RENAMED_METHODS = {
        display_promo_total: :display_discount_total,
        display_shipment_total: :display_delivery_total,
        display_ship_total: :display_delivery_total,
        shipping_discount: :fulfillment_discount,
        delivery_required?: :delivery_step_required?,
        requires_ship_address?: :shipping_address_required?,
        set_shipments_cost: :set_fulfillments_cost,
        ensure_updated_shipments: :ensure_updated_fulfillments,
        create_proposed_fulfillments: :rebuild_fulfillments!,
        create_proposed_shipments: :rebuild_fulfillments!,
        associate_user!: :associate_customer!,
        update_with_updater!: :recalculate_totals!,
        all_line_items: :line_items
      }.freeze

      # 5.x took a store argument; payment methods now always come from the
      # purchase's own store.
      RENAMED_PAYMENT_METHOD_READERS = %i[
        available_payment_methods
        collect_payment_methods
        collect_frontend_payment_methods
      ].freeze

      included do
        include Spree::DeprecatedCustomerAlias

        RENAMED_ATTRIBUTES.each do |legacy_name, current_name|
          alias_attribute legacy_name, current_name
        end
      end

      RENAMED_ATTRIBUTES.each do |legacy_name, current_name|
        define_method(legacy_name) do
          warn_deprecated_name(legacy_name, current_name)
          public_send(current_name)
        end

        define_method(:"#{legacy_name}=") do |value|
          warn_deprecated_name(:"#{legacy_name}=", :"#{current_name}=")
          public_send(:"#{current_name}=", value)
        end
      end

      RENAMED_METHODS.each do |legacy_name, current_name|
        define_method(legacy_name) do |*args, **options, &block|
          warn_deprecated_name(legacy_name, current_name)
          public_send(current_name, *args, **options, &block)
        end
      end

      RENAMED_PAYMENT_METHOD_READERS.each do |legacy_name|
        define_method(legacy_name) do |*|
          warn_deprecated_name(legacy_name, :payment_methods)
          payment_methods
        end
      end

      private

      def warn_deprecated_name(legacy_name, current_name)
        Spree::Deprecation.warn("#{self.class.name}##{legacy_name} is deprecated and will be removed in Spree 6.1. Use ##{current_name} instead.")
      end
    end
  end
end
