module Spree
  module Api
    module V3
      module Admin
        # What a bulk stock level upsert did.
        class BulkStockLevelResultSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize stock_level_count: [:number, comment: 'Stock levels written']

          attributes :stock_level_count
        end
      end
    end
  end
end
