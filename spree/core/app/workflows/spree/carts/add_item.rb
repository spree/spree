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
      # @param price [BigDecimal, String, nil] negotiated unit price — stamps the
      #   line +price_source: 'manual'+ so repricing leaves it alone. Admin
      #   surface only (draft orders); refused once the order is placed.
      def perform(variant:, cart: nil, order: nil, quantity: nil, metadata: {}, options: {}, price: nil)
        if order
          Spree::Deprecation.warn('Calling Spree::Carts::AddItem with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        super(cart: cart, variant: variant, quantity: quantity, metadata: metadata, options: options, price: price)

        step :parse_manual_price unless price.nil?

        # Veto point — purchase limits, B2B eligibility, per-group rules.
        # Outside the transaction: nothing has been written yet, so a
        # rejection costs no rollback.
        run_hooks :validate

        # Both providers are consulted before the transaction opens: they may
        # be external systems, and a database transaction held open across a
        # network call is how a slow warehouse becomes a table of stuck locks.
        # A negotiated price skips the pricing round: the caller has already
        # answered the question the provider would be asked.
        external_step :check_availability
        external_step :resolve_price if price.nil?

        ApplicationRecord.transaction do
          step :add_to_line_item
          step :handle_stock_reservations if cart.in_checkout?
          step :recalculate, with: -> { Spree.cart_recalculate_workflow }
          run_hooks :after_item_added
        end

        success(line_item)
      end

      private

      # finite? is not redundant: BigDecimal parses "NaN" and "Infinity" and
      # neither is negative. reject! rather than failure(cart, message), which
      # would drop the message.
      def parse_manual_price
        reject!(Spree.t('cart_line_item.price_override_not_allowed'), cart) if cart.completed?

        @manual_price = BigDecimal(price.to_s)
        reject!(Spree.t('cart_line_item.invalid_price'), cart) if @manual_price.negative? || !@manual_price.finite?
      rescue ArgumentError
        reject!(Spree.t('cart_line_item.invalid_price'), cart)
      end

      def add_to_line_item
        item_options = options || {}
        requested_quantity = quantity || 1

        # A provider that quoted a real amount is proof the currency is
        # sellable, even when the local catalog holds no price for it — an
        # external system can be the only source for a currency. The internal
        # resolver returns a placeholder with a nil amount when it has none,
        # which is not a quote. A negotiated price is a quote too — the
        # merchant just made it themselves.
        if @manual_price.nil? && resolved_amount.nil? && variant.amount_in(cart.currency).nil?
          failure(variant, "#{variant.name} is not available in #{cart.currency}")
        end

        @line_item = existing_line_item
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

        # Before the save, so the resolved price rides the same write and the
        # quantity-change callback sees the line as already priced.
        apply_resolved_price
        apply_manual_price
        failure(@line_item) unless @line_item.save

        @line_item.reload

        return unless @line_item_created

        owner = @line_item.owner
        owner.tax_provider.estimate(owner, [@line_item], **owner.tax_estimate_inputs)
      end

      # Only external inventory needs asking here — Spree's own stock records
      # are already checked by the line item's availability validator on save,
      # and duplicating that would mean two answers that can disagree.
      def check_availability
        return if cart.store.nil? || cart.store.internal_inventory?

        result = Spree::Carts::CheckAvailability.call(
          cart: cart, items: [{ variant: variant, quantity: resulting_quantity }]
        )
        failure(variant, result.error) if result.failure?

        return if result.value.blank?

        failure(variant, Spree.t(:selected_quantity_not_available, item: variant.name.inspect))
      end

      # Asked before the item exists, so the context carries the quantity the
      # line will end up at — a volume price must reflect the whole line, not
      # the increment.
      def resolve_price
        result = Spree::Carts::PriceItems.new.call(cart: cart, line_items: [pricing_probe_line_item])
        failure(variant, result.error) if result.failure?

        @resolved_price = result.value.first
      end

      # The provider is asked about a line item that does not exist yet, so
      # the answer arrives against a stand-in and is transferred onto the real
      # row once it does.
      def pricing_probe_line_item
        Spree::Carts::PriceItems.probe(cart: cart, variant: variant, quantity: resulting_quantity)
      end

      # The amount the pricing step actually resolved, or nil when nothing
      # priced this line.
      def resolved_amount
        @resolved_price&.at(1)&.amount
      end

      def apply_resolved_price
        return if @resolved_price.blank?

        _probe, price = @resolved_price
        Spree::Carts::PriceItems.apply([[@line_item, price]], persist: false)
      end

      # Stamps the negotiated price after any resolved one, so it wins the
      # write, marks the line manual, and detaches it from whatever price list
      # the resolver may have matched.
      def apply_manual_price
        return if @manual_price.nil?

        @line_item.assign_attributes(
          price: @manual_price,
          price_source: Spree::LineItem::MANUAL_PRICE_SOURCE,
          price_list_id: nil
        )
        # The quantity-change callback must not re-ask the provider for a
        # price this save already carries.
        @line_item.price_resolved = true
      end

      # What the line will hold once this add is applied. Volume pricing and
      # the availability check both care about the whole line, not the
      # increment. +to_i+ because quantity arrives off a request as a string.
      def resulting_quantity
        existing_line_item&.quantity.to_i + (quantity.presence || 1).to_i
      end

      # Memoized because the price and availability steps ask for it before
      # the transaction, and +add_to_line_item+ needs the same row inside it.
      def existing_line_item
        return @existing_line_item if defined?(@existing_line_item)

        @existing_line_item = Spree.line_item_by_variant_finder.new.
          execute(cart: cart, variant: variant, options: options || {})
      end

      def handle_stock_reservations
        result = Spree::StockReservations::Reserve.call(cart: cart)
        failure(line_item, result.error) if result.failure?
      end
    end
  end
end
