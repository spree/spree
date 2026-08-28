module Spree
  module Api
    module V3
      module Admin
        class ChannelSerializer < V3::ChannelSerializer
          typelize store_id: :string,
                   preferred_order_routing_strategy: [:string, nullable: true],
                   preferred_storefront_access: [:string, nullable: true],
                   preferred_guest_checkout: [:boolean, nullable: true],
                   stock_location_ids: [:string, multi: true],
                   default_catalog_id: [:string, nullable: true],
                   market_ids: [:string, multi: true],
                   default_market_id: [:string, nullable: true]

          attributes :preferred_order_routing_strategy,
                     :preferred_storefront_access,
                     :preferred_guest_checkout,
                     created_at: :iso8601, updated_at: :iso8601

          # Fulfillment-origin allowlist; empty means every store location
          # serves this channel.
          attribute :stock_location_ids do |record|
            record.stock_locations.map(&:prefixed_id)
          end

          # When set, only the default catalog's products are visible on this
          # channel; unset means every publication.
          attribute :default_catalog_id do |record|
            record.default_catalog&.prefixed_id
          end

          # Market allowlist; empty means the channel sells into every market
          # of the store.
          attribute :market_ids do |record|
            record.markets.map(&:prefixed_id)
          end

          # The pinned default market, if any. Null means it is derived —
          # read `resolved_default_market` for the effective value.
          attribute :default_market_id do |record|
            record.default_market&.prefixed_id
          end
        end
      end
    end
  end
end
