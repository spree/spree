module Spree
  module Cart
    class AddItem
      prepend Spree::ServiceModule::Base

      def call(order:, variant:, quantity: nil, options: {})
        run :add_to_line_item
        run Spree::Cart::Recalculate
      end

      private

      def add_to_line_item(order:, variant:, quantity: nil, options: {})
        options ||= {}
        quantity ||= 1

        line_item = Spree::LineItem::FindByVariant.new.execute(order: order, variant: variant, options: options)

        line_item_created = line_item.nil?
        if line_item.nil?
          opts = ::Spree::PermittedAttributes.line_item_attributes.each_with_object({}) do |attribute, result|
            result[attribute] = options[attribute]
          end.merge(currency: order.currency).delete_if { |_key, value| value.nil? }

          line_item = order.line_items.new(quantity: quantity,
                                           variant: variant,
                                           options: opts)
        else
          line_item.quantity += quantity.to_i
        end

        line_item.target_shipment = options[:shipment] if options.key? :shipment
        line_item.save!
        ::Spree::TaxRate.adjust(order, [line_item.reload]) if line_item_created
        success(order: order, line_item: line_item, line_item_created: line_item_created, options: options)
      end
    end
  end
end
