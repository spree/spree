module Spree
  module Api
    module V3
      module Seller
        # One of the seller's own ways to ship, or a marketplace method the
        # operator shares with them.
        #
        # Declared on top of the store serializer rather than subclassed from
        # the admin one, like every serializer on this branch. What it leaves
        # out is deliberate: `rate_provider`, `fulfillment_provider` and
        # `pickup_point_provider` are fixed for a seller's method
        # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13), so a
        # seller neither sets them nor needs to read them.
        #
        # `editable` is what the panel renders a shared marketplace method
        # read-only by — a seller sees the operator's method so they know what
        # their goods can already ship with, and cannot change it.
        class DeliveryMethodSerializer < V3::DeliveryMethodSerializer
          typelize admin_name: [:string, nullable: true],
                   storefront_visible: :boolean,
                   tracking_url: [:string, nullable: true],
                   editable: :boolean,
                   delivery_profile_id: [:string, nullable: true],
                   delivery_zone_id: [:string, nullable: true],
                   calculator_type: [:string, nullable: true],
                   calculator_preferences: ['Record<string, unknown>', nullable: true]

          attributes :admin_name, :storefront_visible, :tracking_url,
                     created_at: :iso8601, updated_at: :iso8601

          many :delivery_method_rules, key: :rules, resource: proc { Spree.api.seller_delivery_method_rule_serializer }

          # False for a marketplace method the operator shares — it is listed
          # here so the seller can see what already ships their goods, and the
          # API refuses to write it.
          attribute :editable do |record|
            record.seller_id.present?
          end

          attribute :delivery_profile_id do |record|
            record.delivery_profile&.prefixed_id
          end

          attribute :delivery_zone_id do |record|
            record.delivery_zone&.prefixed_id
          end

          attribute :calculator_type do |record|
            record.calculator&.type
          end

          attribute :calculator_preferences do |record|
            record.calculator.respond_to?(:serialized_preferences) ? record.calculator.serialized_preferences : record.calculator&.preferences
          end
        end
      end
    end
  end
end
