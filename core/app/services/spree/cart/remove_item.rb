module Spree
  module Cart
    class RemoveItem
      prepend Spree::ServiceModule::Base

      def call(order:, variant:, quantity: nil, options: nil)
        options ||= {}
        quantity ||= 1

        ActiveRecord::Base.transaction do
          line_item = remove_from_line_item(order: order, variant: variant, quantity: quantity, options: options)
          Spree::Dependencies.cart_recalculate_service.constantize.call(line_item: line_item,
                                                                        order: order,
                                                                        options: options)
          notify_order_stream(order: order, line_item: line_item, variant: variant, quantity: quantity)
          success(line_item)
        end
      end

      private

      def notify_order_stream(order:, line_item:, variant:, quantity:, options: nil)
        event_store.publish(
          EventStore::Publish::Cart::Update.new(data: { order: order.as_json, line_item: line_item, variant: variant, quantity: quantity }),
          stream_name: "order_#{order.number}_customer_#{order.user.id}" # check if usable with _customer
        )
      end

      def remove_from_line_item(order:, variant:, quantity:, options:)
        line_item = Spree::Dependencies.line_item_by_variant_finder.constantize.new.execute(order: order, variant: variant, options: options)

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
