module Spree
  module Api
    module V3
      module Admin
        class ChannelSerializer < V3::ChannelSerializer
          typelize store_id: :string,
                   preferred_order_routing_strategy: [:string, nullable: true],
                   preferred_storefront_access: [:string, nullable: true],
                   preferred_guest_checkout: [:boolean, nullable: true],
                   stock_location_ids: [:string, multi: true]

          attributes :preferred_order_routing_strategy,
                     :preferred_storefront_access,
                     :preferred_guest_checkout,
                     created_at: :iso8601, updated_at: :iso8601

          # Fulfillment-origin allowlist; empty means every store location
          # serves this channel.
          attribute :stock_location_ids do |record|
            record.stock_locations.map(&:prefixed_id)
          end
        end
      end
    end
  end
end
