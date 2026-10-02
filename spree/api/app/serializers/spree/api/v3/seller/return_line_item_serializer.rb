# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # One line of a return.
        #
        # Names what came back on the line itself: a variant carries a SKU and
        # its option values but no product name, so a card built from the
        # variant alone would show a bare id for anything unSKU'd.
        class ReturnLineItemSerializer < V3::ReturnLineItemSerializer
          typelize name: [:string, nullable: true]

          attribute :name do |line|
            line.line_item&.name || line.variant&.name
          end

          expandable :one, :variant, :seller_variant_serializer
        end
      end
    end
  end
end
