module Spree
  module Cart
    class AddItem
      prepend Spree::ServiceModule::Base

      def call(order:, variant:, quantity: nil, public_metadata: {}, private_metadata: {}, options: {})
        ApplicationRecord.transaction do
          run :add_to_line_item
          # run :notify_order_stream
          run Spree::Dependencies.cart_recalculate_service.constantize
        end
      end

      private

      def notify_order_stream(order:, line_item:, line_item_created:, options: nil)
        # event_store.publish(
        #   EventStore::Publish::Cart::Add.new(data: { order: order, variant: line_item.variant, quantity: line_item.quantity }),
        #   stream_name: "order_#{line_item.order.number}_customer_#{line_item.order.user.id}" # check if usable with _customer
        # )

        success(order: order, line_item: line_item, line_item_created: line_item_created, options: options)
      end

      def add_to_line_item(order:, variant:, quantity: nil, public_metadata: {}, private_metadata: {}, options: {})
        options ||= {}
        quantity ||= 1

        line_item = Spree::Dependencies.line_item_by_variant_finder.constantize.new.execute(order: order, variant: variant, options: options)

        line_item_created = line_item.nil?
        if line_item.nil?
          opts = ::Spree::PermittedAttributes.line_item_attributes.flatten.each_with_object({}) do |attribute, result|
            result[attribute] = options[attribute]
          end.merge(currency: order.currency).delete_if { |_key, value| value.nil? }

          line_item = order.line_items.new(quantity: quantity,
                                           variant: variant,
                                           options: opts)
        else
          line_item.quantity += quantity.to_i
        end

        line_item.target_shipment = options[:shipment] if options.key? :shipment
        line_item.public_metadata = public_metadata.to_h if public_metadata
        line_item.private_metadata = private_metadata.to_h if private_metadata

        return failure(line_item) unless line_item.save

        line_item.reload.update_price

        ::Spree::TaxRate.adjust(order, [line_item]) if line_item_created
        success(order: order, line_item: line_item, line_item_created: line_item_created, options: options)
      end
    end
  end
end
