module Spree
  module Api
    module V3
      module Admin
        # The body of the shared bulk tag actions (Spree::Api::V3::BulkOperations).
        # Each controller declares it as `BulkTagsParams` with only these fields,
        # so the published component is the same wherever it is used.
        class BulkTagsRequestSchema < Spree::Api::V3::RequestSchema
          attribute :ids, :array, of: :id,
            required: true,
            description: 'The records to change. Records the caller cannot update are skipped; an empty list changes nothing.'
          attribute :tags, :array, of: :string, required: true, example: %w[vip wholesale]
        end
      end
    end
  end
end
