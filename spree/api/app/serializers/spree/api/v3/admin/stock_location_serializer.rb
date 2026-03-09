module Spree
  module Api
    module V3
      module Admin
        class StockLocationSerializer < V3::StockLocationSerializer
          typelize active: :boolean, default: :boolean, backorderable_default: :boolean,
                   propagate_all_variants: :boolean

          attributes :active, :default, :backorderable_default, :propagate_all_variants,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
