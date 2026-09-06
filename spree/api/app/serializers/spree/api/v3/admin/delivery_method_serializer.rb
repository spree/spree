module Spree
  module Api
    module V3
      module Admin
        class DeliveryMethodSerializer < V3::DeliveryMethodSerializer
          typelize admin_name: [:string, nullable: true],
                   deposit_percentage: [:string, nullable: true],
                   balance_due_label: [:string, nullable: true],
                   fulfillment_provider: :string, pickup_point_provider: [:string, nullable: true],
                   rate_provider: [:string, nullable: true],
                   storefront_visible: :boolean, tracking_url: [:string, nullable: true],
                   tax_category_id: [:string, nullable: true],
                   delivery_profile_id: :string,
                   delivery_origin_group_id: [:string, nullable: true],
                   delivery_zone_id: [:string, nullable: true],
                   stock_location_ids: [:string, multi: true],
                   calculator_type: [:string, nullable: true],
                   calculator_preferences: ['Record<string, unknown>', nullable: true],
                   markup_flat: [:string, nullable: true],
                   markup_percent: [:string, nullable: true],
                   available_to_sellers: :boolean,
                   seller_id: [:string, nullable: true],
                   seller_name: [:string, nullable: true]

          attributes :admin_name, :fulfillment_provider, :pickup_point_provider, :deposit_percentage, :balance_due_label,
                     :rate_provider, :storefront_visible, :tracking_url,
                     :markup_flat, :markup_percent, :available_to_sellers,
                     created_at: :iso8601, updated_at: :iso8601, deleted_at: :iso8601

          # Which seller runs this method, so the operator's list can say
          # whose it is. Null is the marketplace's own
          # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
          attribute :seller_id do |record|
            record.seller&.prefixed_id
          end

          attribute :seller_name do |record|
            record.seller&.name
          end

          many :services, resource: proc { Spree.api.admin_delivery_method_service_serializer }

          # Embedded so a list of methods can be summarized by their
          # eligibility without a request per method.
          many :delivery_method_rules, key: :rules, resource: proc { Spree.api.admin_delivery_method_rule_serializer }

          attribute :tax_category_id do |record|
            record.tax_category&.prefixed_id
          end

          attribute :delivery_profile_id do |record|
            record.delivery_profile&.prefixed_id
          end

          attribute :delivery_origin_group_id do |record|
            record.delivery_origin_group&.prefixed_id
          end

          attribute :delivery_zone_id do |record|
            record.delivery_zone&.prefixed_id
          end

          attribute :stock_location_ids do |record|
            record.pickup_locations.map(&:prefixed_id)
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
