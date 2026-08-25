module Spree
  module Carts
    # Applies a batch of item changes to a cart in one pass — the single gate
    # for every item mutation that is not a plain add-increment (bulk
    # payloads, a quantity edit, a removal). AddItem stays the increment
    # ("add 2 more"); this workflow SETS quantity, and quantity zero removes.
    #
    # Two things make it worth a workflow rather than a loop over AddItem.
    # Extensions get one veto point covering every non-increment path, and
    # the cart recalculates ONCE for the whole batch instead of once per
    # item — the money math is the expensive part, so a dozen items cost
    # roughly one item's work.
    #
    # Rejections are per item, not per batch: a validate handler that vetoes
    # one line skips that line and the rest still apply, so a customer
    # restoring a saved cart keeps everything still purchasable and hears
    # about what was dropped. The skipped items come back as +warnings+
    # (see Spree::Carts::ItemWarning) beside a successful result.
    class UpsertItems < Spree::Workflow
      hooks :validate, :after_items_upserted

      # Readers a :validate handler uses. variant/quantity/metadata describe
      # the item currently being validated — the same reader names AddItem
      # exposes, so one handler class registers on both keys unchanged.
      # +items+ is the whole resolved batch, for rules that need to see it
      # (a per-order unit cap, a mixed-category restriction).
      attr_reader :variant, :quantity, :metadata, :items, :warnings

      # @param cart [Spree::Cart, Spree::Order]
      # @param items [Array<Hash>] :variant_id (prefixed or raw), :quantity,
      #   :metadata. Quantity defaults to 1; zero or less removes.
      # @return [Spree::ServiceModule::Result] value is the cart
      def perform(cart:, items:)
        super
        @warnings = []

        step :resolve_items
        return success(cart) if resolved_items.empty?

        # Before the transaction: both may be external systems, and a database
        # transaction held open across a network call is how a slow warehouse
        # becomes a table of stuck locks.
        external_step :check_availability
        external_step :resolve_prices

        ApplicationRecord.transaction do
          step :apply_items
          step :handle_stock_reservations if cart.in_checkout?
          step :recalculate, with: -> { Spree.cart_recalculate_workflow } if recalculate?
          run_hooks :after_items_upserted
        end

        # Warnings ride on the cart itself — the same channel the
        # out-of-stock sweep uses — so they reach the serializer without
        # every caller forwarding them by hand. Set after the reload, which
        # would otherwise drop them.
        cart.reload
        cart.warnings |= warnings.map(&:to_h) if warnings.any?

        success(cart)
      end

      private

      attr_reader :resolved_items

      # The cart side recalculates here because nothing else will. The order
      # side overrides this: admin edits run items, fulfillments and coupons
      # as one pipeline and recalculate once at the end of it.
      def recalculate?
        true
      end

      # A customer restoring a saved cart should keep whatever is still
      # purchasable, so a bad line becomes a warning. A merchant editing an
      # order should not: a struck-out or repriced row silently not applying
      # is worse than the edit failing, so the order twin turns this off.
      def partial_success?
        true
      end

      # One pass for lookup and currency checks, before anything is written,
      # so a batch naming an unknown variant fails before it has half
      # applied.
      def resolve_items
        store = cart.store || Spree::Current.store

        @resolved_items = Array(items).filter_map do |item_params|
          item_params = item_params.to_h.deep_symbolize_keys
          quantity = (item_params[:quantity] || 1).to_i
          variant = resolve_variant(store, item_params[:variant_id], removing: quantity <= 0)
          next if variant.nil?

          Spree::Carts::ResolvedItem.new(
            variant: variant,
            quantity: quantity,
            metadata: item_params[:metadata].to_h
          )
        end
      end

      # Only external inventory is asked here: Spree's own records are already
      # checked by the line item's availability validator on save, and two
      # answers that can disagree is worse than one.
      def check_availability
        @unsupplyable_variant_ids = Set.new
        return if cart.store.nil? || cart.store.internal_inventory?

        return if additions.empty?

        result = Spree::Carts::CheckAvailability.call(
          cart: cart, items: additions.map { |item| { variant: item.variant, quantity: item.quantity } }
        )
        failure(cart, result.error) if result.failure?

        @unsupplyable_variant_ids = Array(result.value).map { |variant, _quantity| variant.id }.to_set
      end

      # One provider round per batch rather than one per line: a fifty-line
      # cart restore must not become fifty calls to an ERP.
      def resolve_prices
        return if additions.empty?

        probes = additions.map do |item|
          Spree::Carts::PriceItems.probe(cart: cart, variant: item.variant, quantity: item.quantity)
        end

        result = Spree::Carts::PriceItems.new.call(cart: cart, line_items: probes)
        failure(cart, result.error) if result.failure?

        @resolved_prices = Array(result.value).index_by { |probe, _price| probe.variant_id }
      end

      def additions
        @additions ||= resolved_items.reject(&:remove?)
      end

      def apply_resolved_price(line_item)
        resolution = resolved_prices[line_item.variant_id]
        return if resolution.blank?

        _probe, price = resolution
        Spree::Carts::PriceItems.apply([[line_item, price]], persist: false)
      end

      def resolved_prices
        @resolved_prices ||= {}
      end

      def unsupplyable?(item)
        @unsupplyable_variant_ids.include?(item.variant.id)
      end

      def apply_items
        resolved_items.each_with_index do |item, index|
          next unless validated?(item, index)

          line_item = Spree.line_item_by_variant_finder.new.execute(owner: cart, variant: item.variant)

          if item.remove?
            line_item&.destroy!
            next
          end

          # A provider that already quoted this line is proof the currency is
          # sellable, even when the local catalog holds no price for it — an
          # external system can be the only source for a currency.
          if resolved_prices[item.variant.id]&.at(1)&.amount.nil? && item.variant.amount_in(cart.currency).nil?
            message = Spree.t('cart_line_item.currency_unavailable', li_name: item.variant.name, currency: cart.currency)
            failure(item.variant, message) unless partial_success?

            warn(index, item, :currency_unavailable, message)
            next
          end

          if unsupplyable?(item)
            message = Spree.t(:selected_quantity_not_available, item: item.variant.name.inspect)
            failure(item.variant, message) unless partial_success?

            warn(index, item, :selected_quantity_not_available, message)
            next
          end

          apply_item(item, line_item, index)
        end
      end

      # Dispatches :validate for one item with that item's readers bound, and
      # converts a handler's rejection into a warning instead of failing the
      # batch. FailureSignal is what reject! raises; catching it here is the
      # deliberate difference between this workflow and every other one.
      def validated?(item, index)
        bind_current_item(item)
        run_hooks :validate
        true
      rescue Spree::Workflow::FailureSignal
        raise unless partial_success?

        rejection = errors
        @errors = nil
        warnings << Spree::Carts::ItemWarning.new(
          item_index: index,
          variant: item.variant,
          code: rejection.details.values.flatten.first&.dig(:error) || :rejected,
          message: rejection.full_messages.to_sentence
        )
        false
      ensure
        bind_current_item(nil)
      end

      def bind_current_item(item)
        @variant = item&.variant
        @quantity = item&.quantity
        @metadata = item&.metadata || {}
      end

      def apply_item(item, line_item, index)
        if line_item
          line_item.quantity = item.quantity
          line_item.metadata = line_item.metadata.merge(item.metadata) if item.metadata.present?
        else
          line_item = cart.line_items.new(
            quantity: item.quantity,
            variant: item.variant,
            options: { currency: cart.currency }
          )
          line_item.metadata = item.metadata if item.metadata.present?
        end

        created = line_item.new_record?
        # Before the save, so the resolved price rides the same write and the
        # quantity-change callback sees the line as already priced.
        apply_resolved_price(line_item)

        # A line that won't save — most often the stock availability
        # validator — is this item's problem, not the batch's. Failing here
        # would roll back every other line, which is exactly what a customer
        # restoring a saved cart must not lose.
        unless line_item.save
          failure(line_item) unless partial_success?

          warn(index, item, line_item.errors.details.values.flatten.first&.dig(:error) || :invalid,
               line_item.errors.full_messages.to_sentence)
          return
        end

        line_item.reload
        return unless created

        # Per-market provider rather than a global one, and carrying the same
        # typed inputs as a full recalculation so a single new line is taxed
        # with the buyer's registration and exemptions.
        owner = line_item.owner
        owner.tax_provider.estimate(owner, [line_item], **owner.tax_estimate_inputs)
      end

      def handle_stock_reservations
        result = Spree::StockReservations::Reserve.call(cart: cart)
        failure(cart, result.error) if result.failure?
      end

      # Adds resolve through the store, so a variant belonging to another
      # tenant is a 404 rather than a cross-store add. Removals resolve
      # through the cart's own items instead: the line is already there, and
      # a product that has since been deleted or unpublished has left
      # store.variants — refusing to remove it would strand the customer
      # with a line they cannot get rid of.
      def resolve_variant(store, variant_id, removing: false)
        return nil if variant_id.blank?

        if removing
          cart.line_items.detect { |line_item| line_item.variant_id.to_s == variant_id.to_s }&.variant ||
            Spree::Variant.with_deleted.find_by_param(variant_id)
        else
          store.variants.find_by_param(variant_id) ||
            raise(ActiveRecord::RecordNotFound.new("Variant '#{variant_id}' not found in this store", 'Spree::Variant', 'id', variant_id))
        end
      end

      def warn(index, item, code, message)
        warnings << Spree::Carts::ItemWarning.new(item_index: index, variant: item.variant, code: code, message: message)
      end
    end
  end
end
