module Spree
  module Api
    module V3
      module Admin
        class ChannelSerializer < V3::ChannelSerializer
          typelize store_id: :string,
                   preferred_order_routing_strategy: [:string, nullable: true],
                   preferred_storefront_access: [:string, nullable: true],
                   preferred_guest_checkout: [:boolean, nullable: true]

          attributes :preferred_order_routing_strategy,
                     :preferred_storefront_access,
                     :preferred_guest_checkout,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
