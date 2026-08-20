module Spree
  module Carts
    class AddItem < Spree::Workflow
      # Line item attributes a caller may set through `options`.
      ITEM_OPTIONS = [:id, :variant_id, :quantity].freeze

      hooks :validate, :after_item_added

      # Hook handlers read these plus the argument readers. Both are nil
      # when the :validate hook runs — it fires before the item is built.
      attr_reader :line_item, :line_item_created

      # @param cart [Spree::Cart, Spree::Order] draft orders ride the same pipeline
      # @param variant [Spree::Variant]
      # @param quantity [Integer, nil] defaults to 1
      # @param metadata [Hash] schemaless developer metadata stored on the line item
      def perform(variant:, cart: nil, order: nil, quantity: nil, metadata: {}, options: {})
        if order
          Spree::Deprecation.warn('Calling Spree::Carts::AddItem with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        super(cart: cart, variant: variant, quantity: quantity, metadata: metadata, options: options)

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
          # `LineItem#options=` mass-assigns, so the caller's hash is narrowed
          # first — `options` must not be a way to set arbitrary attributes.
          # Extensions widen this through the model's permitted attributes.
          writable = ITEM_OPTIONS +
                     ::Spree::LineItem.additional_permitted_attributes.flat_map { |a| a.is_a?(Hash) ? a.keys : a }

          opts = item_options.symbolize_keys.slice(*writable).
                 merge(currency: cart.currency).
                 delete_if { |_key, value| value.nil? }

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

        @line_item.metadata = metadata.to_h if metadata.present?

        failure(@line_item) unless @line_item.save

        @line_item.reload.recalculate_price

        return unless @line_item_created

        owner = @line_item.owner
        owner.tax_provider.estimate(owner, [@line_item], **owner.tax_estimate_inputs)
      end

      def handle_stock_reservations
        result = Spree::StockReservations::Reserve.call(cart: cart)
        failure(line_item, result.error) if result.failure?
      end
    end
  end
end
