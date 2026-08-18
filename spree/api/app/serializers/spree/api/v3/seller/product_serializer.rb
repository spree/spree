module Spree
  module Api
    module V3
      module Seller
        # A seller's own product, as they manage it.
        #
        # Extends the store serializer, NOT the admin one, deliberately. The
        # admin serializer's nested associations (`variants`, `channels`,
        # `product_publications`) render through admin serializers that carry
        # operator data — cost prices, publication state, internal metadata —
        # and a seller must not read those even on their own product. The
        # store serializer's nested pieces are all customer-safe, so building
        # up from there means nothing leaks by inheritance.
        #
        # On top of the public view, a seller needs `status` (their product may
        # be a draft the storefront cannot see yet) and timestamps.
        class ProductSerializer < V3::ProductSerializer
          typelize status: :string

          attributes :status, created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
