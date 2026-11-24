module Spree
  module Api
    module V3
      module Admin
        # What adding products to, or removing them from, categories did.
        class BulkProductCategoriesResultSerializer < BulkProductResultSerializer
          typelize category_count: [:number, comment: 'Categories the action applied to']

          attributes :category_count
        end
      end
    end
  end
end
