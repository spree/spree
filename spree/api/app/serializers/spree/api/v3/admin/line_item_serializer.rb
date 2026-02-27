module Spree
  module Api
    module V3
      module Admin
        # Admin API Line Item Serializer
        # Extends the store serializer with metadata visibility
        class LineItemSerializer < V3::LineItemSerializer
          typelize metadata: 'Record<string, unknown> | null'

          attribute :metadata do |line_item|
            line_item.metadata.presence
          end
        end
      end
    end
  end
end
