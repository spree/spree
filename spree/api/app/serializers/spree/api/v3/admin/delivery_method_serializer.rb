module Spree
  module Api
    module V3
      module Admin
        class DeliveryMethodSerializer < V3::DeliveryMethodSerializer
          typelize admin_name: [:string, nullable: true], fulfillment_type: :string,
                   fulfillment_provider: :string, pickup_point_provider: [:string, nullable: true],
                   rate_provider: [:string, nullable: true],
                   storefront_visible: :boolean, tracking_url: [:string, nullable: true],
                   tax_category_id: [:string, nullable: true],
                   delivery_zone_ids: [:string, multi: true],
                   stock_location_ids: [:string, multi: true],
                   calculator_type: [:string, nullable: true],
                   calculator_preferences: ['Record<string, unknown>', nullable: true],
                   markup_flat: [:string, nullable: true],
                   markup_percent: [:string, nullable: true]

          attributes :admin_name, :fulfillment_type, :fulfillment_provider, :pickup_point_provider,
                     :rate_provider, :storefront_visible, :tracking_url,
                     :markup_flat, :markup_percent,
                     created_at: :iso8601, updated_at: :iso8601, deleted_at: :iso8601

          many :services, resource: proc { Spree.api.admin_delivery_method_service_serializer }

          attribute :tax_category_id do |record|
            record.tax_category&.prefixed_id
          end

          attribute :delivery_zone_ids do |record|
            record.delivery_zones.map(&:prefixed_id)
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
