module Spree
  module Carts
    class AddItem < Spree::Workflow
      argument :cart, [Spree::Cart, Spree::Order]
      argument :variant, Spree::Variant
      argument :quantity, default: nil
      argument :metadata, default: {}
      argument :public_metadata, default: {}
      argument :private_metadata, default: {}
      argument :options, default: {}
      alias_argument order: :cart, deprecated: true
      returns :line_item

      transaction do
        step :add_to_line_item, provides: [:line_item, :line_item_created]
        step :handle_stock_reservations, if: -> { cart.in_checkout? }
        step :recalculate, with: -> { Spree.cart_recalculate_workflow }
        run_hooks :after_item_added
      end

      private

      def add_to_line_item
        item_options = options || {}
        requested_quantity = quantity || 1

        return failure(variant, "#{variant.name} is not available in #{cart.currency}") if variant.amount_in(cart.currency).nil?

        line_item = Spree.line_item_by_variant_finder.new.execute(cart: cart, variant: variant, options: item_options)

        line_item_created = line_item.nil?
        if line_item.nil?
          opts = ::Spree::PermittedAttributes.line_item_attributes.flatten.each_with_object({}) do |attribute, result|
            result[attribute] = item_options[attribute]
          end.merge(currency: cart.currency).delete_if { |_key, value| value.nil? }

          line_item = cart.line_items.new(quantity: requested_quantity,
                                          variant: variant,
                                          options: opts)
        else
          line_item.quantity += requested_quantity.to_i
        end

        # `metadata` is the primary API param (maps to private_metadata).
        # Legacy `public_metadata`/`private_metadata` params kept for backward compatibility.
        resolved_metadata = metadata.presence || private_metadata
        line_item.metadata = resolved_metadata.to_h if resolved_metadata.present?
        line_item.public_metadata = public_metadata.to_h if public_metadata.present?

        return failure(line_item) unless line_item.save

        line_item.reload.recalculate_price

        ::Spree.tax_provider.estimate(line_item.owner, [line_item]) if line_item_created
        { line_item: line_item, line_item_created: line_item_created }
      end

      def handle_stock_reservations
        result = Spree::StockReservations::Reserve.call(cart: cart)
        return failure(line_item, result.error) if result.failure?
      end
    end
  end
end
