module Spree
  module Api
    module V3
      module Seller
        # What a bulk product action did.
        class BulkProductResultSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize product_count: [:number, comment: 'Products the action applied to'],
                   skipped_count: [:number, optional: true, comment: 'Present only when something was skipped']

          attributes :product_count

          attribute :skipped_count, if: proc { |result| result.key?(:skipped_count) } do |result|
            result[:skipped_count]
          end
        end
      end
    end
  end
end
