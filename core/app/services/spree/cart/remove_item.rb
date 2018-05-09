module Spree
  module Cart
    class RemoveItem
      prepend Spree::ServiceModule::Base

      def call(order:, variant:, quantity: nil, options: nil)
        options ||= {}
        quantity ||= 1

        ActiveRecord::Base.transaction do
          line_item = remove_from_line_item(order: order, variant: variant, quantity: quantity, options: options)
          Spree::Cart::Recalculate.new.call(line_item: line_item, order: order, options: options)
          success(line_item)
        end
      end

      private

      def remove_from_line_item(order:, variant:, quantity:, options:)
        line_item = Spree::LineItem::FindByVariant.new.execute(order: order, variant: variant, options: options)

        raise ActiveRecord::RecordNotFound if line_item.nil?

        line_item.quantity -= quantity
        line_item.target_shipment = options[:shipment]

        if line_item.quantity.zero?
          order.line_items.destroy(line_item)
        else
          line_item.save!
        end

        line_item
      end
    end
  end
end
