module Spree
  module Api
    module V3
      module Admin
        class ChannelSerializer < V3::ChannelSerializer
          typelize store_id: :string,
                   order_routing_strategy: [:string, nullable: true, comment: 'Order routing strategy; null inherits the store setting. Built-in: rules. Extensions may register more.'],
                   stock_location_ids: [:string, multi: true],
                   default_catalog_id: [:string, nullable: true]

          attributes created_at: :iso8601, updated_at: :iso8601

          preference_attributes Spree::Channel, :storefront_access, :guest_checkout

          api_type_attributes :order_routing_strategy

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
