module Spree
  module Api
    module V3
      module Admin
        # What adding products to, or removing them from, collections did.
        class BulkProductCollectionsResultSerializer < BulkProductResultSerializer
          typelize collection_count: [:number, comment: 'Manual collections the action applied to']

          attributes :collection_count
        end
      end
    end
  end
end
