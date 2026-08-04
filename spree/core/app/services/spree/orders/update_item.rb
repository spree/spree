module Spree
  module Orders
    # Draft-order line item update: quantity and metadata in one seam.
    # Recalculates the order only when quantity changed — metadata-only
    # edits carry no money impact. Unlike the cart side (Carts::SetQuantity),
    # drafts hold no checkout stock reservations, so there is nothing to
    # re-reserve here.
    class UpdateItem
      prepend Spree::ServiceModule::Base

      def call(order:, line_item:, quantity: nil, metadata: nil)
        attributes = {}
        attributes[:quantity] = quantity unless quantity.nil?
        attributes[:metadata] = metadata unless metadata.nil?

        quantity_changing = attributes.key?(:quantity) && attributes[:quantity].to_i != line_item.quantity

        ActiveRecord::Base.transaction do
          return failure(line_item) unless line_item.update(attributes)

          Spree::Orders::Recalculate.call(order: order, line_item: line_item) if quantity_changing
        end

        success(line_item)
      end
    end
  end
end
