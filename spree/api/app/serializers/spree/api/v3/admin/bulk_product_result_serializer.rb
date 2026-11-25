module Spree
  module Api
    module V3
      module Admin
        # What a bulk product action did. Products from other stores, and ones the caller
        # may not change, are left out of the count. Each action adds the
        # figures that describe it, so one type serves them all.
        class BulkProductResultSerializer
          include Alba::Resource
          include Typelizer::DSL

          OPTIONAL = {
            status: [:string, 'The status the products were moved to. Sent by a status change.'],
            skipped_in_review_count: [:number, 'Products waiting for review that a status change left alone. Sent only when there were any.'],
            category_count: [:number, 'Categories the action applied to'],
            collection_count: [:number, 'Collections the action applied to'],
            channel_count: [:number, 'Channels the action applied to'],
            removed: [:number, 'Publications removed. Sent when unpublishing.'],
            tag_count: [:number, 'Tags sent in the request']
          }.freeze

          typelize product_count: [:number, comment: 'Products the action applied to']
          attributes :product_count

          OPTIONAL.each do |name, (type, comment)|
            typelize name => [type, optional: true, comment: comment]
            attribute(name, if: proc { |result| result.key?(name) }) { |result| result[name] }
          end
        end
      end
    end
  end
end
