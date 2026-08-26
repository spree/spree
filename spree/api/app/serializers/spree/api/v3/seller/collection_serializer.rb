module Spree
  module Api
    module V3
      module Seller
        # A collection a seller's product can belong to. Read only — creating
        # or configuring one is the operator's.
        class CollectionSerializer < V3::CollectionSerializer
        end
      end
    end
  end
end
