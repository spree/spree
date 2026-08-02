module Spree
  module Carts
    class AddItem < Spree::Workflow
      hooks :validate, :after_item_added

      # Hook handlers read these plus the argument readers. Both are nil
      # when the :validate hook runs — it fires before the item is built.
      attr_reader :line_item, :line_item_created

      # @param cart [Spree::Cart, Spree::Order] draft orders ride the same pipeline
      # @param variant [Spree::Variant]
      # @param quantity [Integer, nil] defaults to 1
      # @param metadata [Hash] primary API param (maps to private metadata)
      def perform(variant:, cart: nil, order: nil, quantity: nil, metadata: {}, public_metadata: {}, private_metadata: {}, options: {})
        if order
          Spree::Deprecation.warn('Calling Spree::Carts::AddItem with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        super(cart: cart, variant: variant, quantity: quantity, metadata: metadata,
              public_metadata: public_metadata, private_metadata: private_metadata, options: options)

        # Veto point — purchase limits, B2B eligibility, per-group rules.
        # Outside the transaction: nothing has been written yet, so a
        # rejection costs no rollback.
        run_hooks :validate

        ApplicationRecord.transaction do
          step :add_to_line_item
          step :handle_stock_reservations if cart.in_checkout?
          step :recalculate, with: -> { Spree.cart_recalculate_workflow }
          run_hooks :after_item_added
        end

        success(line_item)
      end

      private

      def add_to_line_item
        item_options = options || {}
        requested_quantity = quantity || 1

        failure(variant, "#{variant.name} is not available in #{cart.currency}") if variant.amount_in(cart.currency).nil?

        @line_item = Spree.line_item_by_variant_finder.new.execute(cart: cart, variant: variant, options: item_options)
        @line_item_created = @line_item.nil?

        if @line_item.nil?
          opts = ::Spree::PermittedAttributes.line_item_attributes.flatten.each_with_object({}) do |attribute, result|
            result[attribute] = item_options[attribute]
          end.merge(currency: cart.currency).delete_if { |_key, value| value.nil? }

          @line_item = cart.line_items.new(quantity: requested_quantity,
                                           variant: variant,
                                           options: opts)
        else
          @line_item.quantity += requested_quantity.to_i
        end

        # Pins inventory placement to a specific fulfillment (admin
        # post-placement adds); :shipment is the legacy option key.
        target = item_options[:fulfillment] || item_options[:shipment]
        @line_item.target_fulfillment = target if target

        # `metadata` is the primary API param (maps to private_metadata).
        # Legacy `public_metadata`/`private_metadata` params kept for backward compatibility.
        resolved_metadata = metadata.presence || private_metadata
        @line_item.metadata = resolved_metadata.to_h if resolved_metadata.present?
        @line_item.public_metadata = public_metadata.to_h if public_metadata.present?

        failure(@line_item) unless @line_item.save

        @line_item.reload.recalculate_price

        ::Spree.tax_provider.estimate(@line_item.owner, [@line_item]) if @line_item_created
      end

      def handle_stock_reservations
        result = Spree::StockReservations::Reserve.call(cart: cart)
        failure(line_item, result.error) if result.failure?
      end
    end
  end
end
