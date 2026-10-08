module Spree
  module Api
    module V3
      module Admin
        class ChannelSerializer < V3::ChannelSerializer
          typelize store_id: :string,
                   preferred_order_routing_strategy: [:string, nullable: true, comment: 'Order routing strategy; null inherits the store setting. Built-in: rules. Extensions may register more.'],
                   preferred_storefront_access: [:string, nullable: true],
                   preferred_guest_checkout: [:boolean, nullable: true],
                   stock_location_ids: [:string, multi: true],
                   default_catalog_id: [:string, nullable: true]

          attributes :preferred_storefront_access,
                     :preferred_guest_checkout,
                     created_at: :iso8601, updated_at: :iso8601

          api_type_attributes :preferred_order_routing_strategy

          # Fulfillment-origin allowlist; empty means every store location
          # serves this channel.
          attribute :stock_location_ids do |record|
            record.stock_locations.map(&:prefixed_id)
          end

          # When set, only the default catalog's products are visible on this
          # channel; unset means every publication.
          prefixed_id_attributes :default_catalog
        end
      end
    end
  end
end
