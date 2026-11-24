module Spree
  module Api
    module V3
      module Admin
        # What a bulk status change did.
        class BulkProductStatusResultSerializer < BulkProductResultSerializer
          typelize status: [:string, comment: 'The status the products were moved to'],
                   skipped_in_review_count: [:number, optional: true,
                                                      comment: 'Present only when products waiting for review were left alone']

          attributes :status

          attribute :skipped_in_review_count, if: proc { |result| result.key?(:skipped_in_review_count) } do |result|
            result[:skipped_in_review_count]
          end
        end
      end
    end
  end
end
