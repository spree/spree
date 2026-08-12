module Spree
  module Api
    module V3
      module Admin
        class DeliveryProfileSerializer < BaseSerializer
          typelize name: :string, default: :boolean, position: [:number, nullable: true],
                   kind: :string, digital: :boolean,
                   offers_pickup: :boolean, offers_shipping: :boolean,
                   stock_location_ids: [:string, multi: true],
                   origin_groups: ['Array<{ id: string; name: string | null; position: number | null; stock_location_ids: Array<string> }>'],
                   products_count: :number, delivery_methods_count: :number,
                   delivery_zones_count: :number

          attributes :name, :default, :position,
                     created_at: :iso8601, updated_at: :iso8601

          # The STI class in wire form (`shipping`, `digital`, extension
          # kinds), so clients never parse Ruby class names.
          attribute :kind do |record|
            record.class.name.demodulize.underscore
          end

          attribute :digital, &:digital?

          # Capability badges for admin lists: which products can be collected
          # or shipped is decided by the profile's method set, never declared.
          attribute :offers_pickup, &:offers_pickup?
          attribute :offers_shipping, &:offers_shipping?

          # The default origin group's members — the simple-store surface.
          # Empty means every store location fulfills this profile.
          attribute :stock_location_ids do |record|
            record.default_origin_group&.stock_locations&.map(&:prefixed_id) || []
          end

          # Origin groups partition the profile's fulfillment origins; zones
          # and methods reference one. A null name renders as "All locations".
          attribute :origin_groups do |record|
            record.delivery_origin_groups.map do |group|
              {
                id: group.prefixed_id,
                name: group.name,
                position: group.position,
                stock_location_ids: group.stock_locations.map(&:prefixed_id)
              }
            end
          end

          attribute :products_count do |record|
            record.products.count
          end

          attribute :delivery_methods_count do |record|
            record.delivery_methods.count
          end

          attribute :delivery_zones_count do |record|
            record.delivery_zones.count
          end
        end
      end
    end
  end
end
