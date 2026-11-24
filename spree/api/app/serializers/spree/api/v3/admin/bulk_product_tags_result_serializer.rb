module Spree
  module Api
    module V3
      module Admin
        # What adding tags to, or removing them from, products did.
        class BulkProductTagsResultSerializer < BulkProductResultSerializer
          typelize tag_count: [:number, comment: 'Tags sent in the request']

          attributes :tag_count
        end
      end
    end
  end
end
