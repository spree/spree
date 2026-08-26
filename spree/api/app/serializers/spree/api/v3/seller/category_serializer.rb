module Spree
  module Api
    module V3
      module Seller
        # A category a seller may file a product under. Read only — the
        # marketplace owns its taxonomy.
        class CategorySerializer < V3::CategorySerializer
        end
      end
    end
  end
end
