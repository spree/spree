module Spree
  module Api
    module V3
      module Admin
        class DeliveryOriginGroupSerializer < BaseSerializer
          typelize name: [:string, nullable: true], position: [:number, nullable: true],
                   delivery_profile_id: :string,
                   stock_location_ids: [:string, multi: true],
                   delivery_zones_count: :number, delivery_methods_count: :number

          attributes :name, :position,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :delivery_profile_id do |record|
            record.delivery_profile&.prefixed_id
          end

          # Empty means every store location.
          attribute :stock_location_ids do |record|
            record.stock_locations.map(&:prefixed_id)
          end

          attribute :delivery_zones_count do |record|
            record.delivery_zones.count
          end

          attribute :delivery_methods_count do |record|
            record.delivery_methods.count
          end
        end
      end
    end
  end
end
