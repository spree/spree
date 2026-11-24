module Spree
  module Api
    module V3
      module Admin
        # What a bulk product action did. Products from other stores, and ones the caller
        # may not change, are left out of the count.
        class BulkProductResultSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize product_count: [:number, comment: 'Products the action applied to']

          attributes :product_count
        end
      end
    end
  end
end
