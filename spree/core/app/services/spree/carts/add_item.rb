module Spree
  module Carts
    class AddItem
      prepend Spree::ServiceModule::Base

      def call(cart: nil, order: nil, variant: nil, quantity: nil, metadata: {}, public_metadata: {}, private_metadata: {}, options: {})
        if order
          Spree::Deprecation.warn('Calling Spree::Carts::AddItem with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        rewrite_input!(remove: [:order], cart: cart)
        ApplicationRecord.transaction do
          run :add_to_line_item
          run :handle_stock_reservations
          run Spree.cart_recalculate_service
        end
      end

      private

      def add_to_line_item(cart:, variant:, quantity: nil, metadata: {}, public_metadata: {}, private_metadata: {}, options: {})
        options ||= {}
        quantity ||= 1

        return failure(variant, "#{variant.name} is not available in #{cart.currency}") if variant.amount_in(cart.currency).nil?

        line_item = Spree.line_item_by_variant_finder.new.execute(cart: cart, variant: variant, options: options)

        line_item_created = line_item.nil?
        if line_item.nil?
          opts = ::Spree::PermittedAttributes.line_item_attributes.flatten.each_with_object({}) do |attribute, result|
            result[attribute] = options[attribute]
          end.merge(currency: cart.currency).delete_if { |_key, value| value.nil? }

          line_item = cart.line_items.new(quantity: quantity,
                                           variant: variant,
                                           options: opts)
        else
          line_item.quantity += quantity.to_i
        end


        # `metadata` is the primary API param (maps to private_metadata).
        # Legacy `public_metadata`/`private_metadata` params kept for backward compatibility.
        resolved_metadata = metadata.presence || private_metadata
        line_item.metadata = resolved_metadata.to_h if resolved_metadata.present?
        line_item.public_metadata = public_metadata.to_h if public_metadata.present?

        return failure(line_item) unless line_item.save

        line_item.reload.recalculate_price

        ::Spree.tax_provider.estimate(line_item.owner, [line_item]) if line_item_created
        success(cart: cart, line_item: line_item, line_item_created: line_item_created, options: options)
      end

      def handle_stock_reservations(cart:, line_item:, line_item_created:, options:)
        if cart.in_checkout?
          result = Spree::StockReservations::Reserve.call(cart: cart)
          return failure(line_item, result.error) if result.failure?
        end

        success(cart: cart, line_item: line_item, line_item_created: line_item_created, options: options)
      end
    end
  end
end
