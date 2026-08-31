module Spree
  module Carts
    # Completes a cart into an immutable order — a three-phase flow with
    # explicit transaction boundaries. External payment I/O never runs inside
    # a DB transaction; everything after a successful charge is small,
    # idempotent and resumable (docs/plans/6.0-cart-order-split.md).
    #
    #   PREPARE  (locked txn)      replay → TTL guard → in-lock recalculation
    #                              → drift guard → validate → draft order +
    #                              copies (unique orders.cart_id)
    #   PAYMENT  (external_step)   offline methods collapse into FINALIZE;
    #                              gateways run outside any txn — a
    #                              pre-capture failure pops the armed
    #                              on_flow_failure compensation
    #   FINALIZE (own txn)         inventory + counters + draft→placed +
    #                              cart.completed_at + UpdateStatuses;
    #                              events after commit
    class Complete < Spree::Workflow
      COMPLETING_TTL = Spree::Cart::COMPLETING_CLAIM_TTL

      hooks :validate, :before_finalize, :after_finalize

      # Hook handlers read this plus the argument readers.
      # +order_group+ is set only when the cart spanned more than one seller.
      attr_reader :order, :order_group

      # @param cart [Spree::Cart, Spree::Order] a draft order funnels into
      #   the same finalize semantics
      # @param expected_total [String, BigDecimal, nil] client-side total for
      #   the drift guard
      # @param payment_pending [Boolean] complete without processing payments
      #   (B2B / invoice-later)
      def perform(cart:, expected_total: nil, payment_pending: false)
        super

        # Legacy signature bridge: completing an already-created draft order
        # (admin/B2B path) reuses the same finalize semantics.
        step :complete_draft_order if cart.is_a?(Spree::Order)

        # P1 — replay: a double-clicked Place Order must get the order back.
        step :replay_completed

        # Last chance to catch a contract price that moved while the customer
        # was in checkout. Outside the lock, since an external provider is a
        # network call and the lock is held across the whole placement.
        external_step :confirm_prices

        cart.with_lock do
          step :guard_concurrent_completion
          step :recalculate_in_lock
          step :verify_expected_total
          step :validate_cart
          step :mark_completing
          step :create_draft_order, on_flow_failure: :rollback_draft_order
        end

        external_step :process_payments if order.payment_required? && !payment_covered?(order)

        run_hooks :before_finalize
        step :finalize_completion
        run_hooks :after_finalize
        # A split checkout answers with the group: it is what the customer
        # bought, and the orders inside it are how it will be fulfilled.
        success(order_group || order)
      rescue ActiveRecord::RecordNotUnique
        # Concurrent completion lost the unique orders.cart_id race —
        # re-enter: the replay step returns the winner's order (or the TTL
        # guard reports completion_in_progress).
        self.class.call(cart: cart.reload, expected_total: expected_total, payment_pending: payment_pending)
      end

      private

      # Admin/B2B draft orders bypass the cart — the order-side completion
      # workflow (Spree::Orders::Complete) owns that path end to end.
      def complete_draft_order
        result = Spree.order_complete_workflow.call(order: cart, payment_pending: payment_pending)
        failure(result.value, result.error) if result.failure?
        halt!(result.value)
      end

      # An existing order here means a previous attempt died mid-pipeline —
      # re-verify payment coverage on drafts, then re-run FINALIZE
      # (idempotent, and the only healer for the crash window between the
      # order commit and the cart stamp).
      def replay_completed
        result = completion_result(cart)
        return if result.nil?

        return replay_group(result) if result.is_a?(Spree::OrderGroup)

        halt!(result) if result.canceled?

        if !result.placed? && result.payment_required? && !payment_covered?(result)
          failure(cart, code: 'payment_failed', message: Spree.t(:payment_processing_failed))
        end

        finalize!(cart, result)
        halt!(result)
      end

      # The split already ran, so the money and the division are settled — what
      # may not have finished is placing the children. Re-running finalize
      # against the group picks up wherever it stopped.
      def replay_group(group)
        @order_group = group
        @order = group.orders.first
        finalize!(cart, order)
        halt!(group)
      end

      def guard_concurrent_completion
        failure(cart, code: 'completion_in_progress') if cart.completion_claimed?
      end

      # In-lock recalculation — the totals about to be charged are computed
      # here, not trusted from earlier requests.
      # Only external pricing is re-confirmed: Spree's own catalog is read
      # inside the lock by the recalculation anyway, so asking twice would buy
      # nothing.
      def confirm_prices
        return if cart.store.nil? || cart.store.internal_pricing?
        return if cart.is_a?(Spree::Order) && cart.completed?

        result = Spree::Carts::PriceItems.new.call(cart: cart)
        failure(cart, code: 'provider_unavailable', message: result.error.to_s) if result.failure?

        @confirmed_prices = result.value
      end

      def recalculate_in_lock
        Spree::Carts::PriceItems.apply(@confirmed_prices) if @confirmed_prices.present?
        cart.recalculate_totals!
      end

      def verify_expected_total
        if expected_total.present? && BigDecimal(expected_total.to_s) != cart.total
          failure(cart, code: 'cart_changed', current_total: cart.total)
        end
      end

      # Core's own checkout requirements first, then the extension veto —
      # a handler that rejects here does so before any money moves and
      # before the draft order exists, so the lock's rollback is the undo.
      def validate_cart
        validation = Spree::Checkout::Requirements.new(cart).call(completion: true)
        failure(cart, code: 'validation_failed', errors: validation) if validation.any?

        run_hooks :validate
      end

      def mark_completing
        cart.update_columns(completing_at: Time.current)
      end

      def create_draft_order
        @order = create_draft_order!(cart)
      end

      def process_payments
        order.process_payments!
        return if payment_covered?(order)

        failure(cart, code: 'payment_failed',
                      message: order.errors.full_messages.to_sentence.presence || Spree.t(:payment_processing_failed))
      rescue Spree::Core::GatewayError => e
        failure(cart, code: 'payment_failed', message: e.message)
      end

      def finalize_completion
        finalize!(cart, order)
      end

      # Y3 — armed when PREPARE commits; a pre-capture payment failure pops
      # it. Post-capture (or covered net-terms) failures must resume through
      # the sweeper instead — the draft is never destroyed once money moved
      # or completion could still finalize.
      def rollback_draft_order
        return if order.nil?
        # Once the checkout has divided, this is no longer a lone draft that can
        # be thrown away: its money sits on the group and its siblings hold the
        # rest of the basket. A failure after that point resumes through the
        # sweeper like any other finalize failure.
        return if order_group.present?
        return if order.payments.valid.completed.any? || payment_covered?(order)

        ApplicationRecord.transaction do
          order.payments.update_all(order_id: nil, cart_id: cart.id)
          order.payment_sessions.update_all(order_id: nil, cart_id: cart.id)
          order.stock_reservations.update_all(order_id: nil, cart_id: cart.id)
          Spree::CouponCode.where(order_id: order.id).update_all(order_id: nil, cart_id: cart.id)
          order.reload.destroy!
          cart.update_columns(completing_at: nil)
        end
      end

      # Exactly one of these is ever set: the bare order a single-partition
      # cart completed into, or the group a multi-seller one did.
      def completion_result(cart)
        cart.order_group || cart.order
      end

      # P7 — the copy contract: the order receives copies (line items with
      # typed money lines re-pointed, fulfillments + selected rates, address
      # copies); money records (payments, sessions, reservations, coupon
      # codes) re-point — external transaction references must never fork.
      def create_draft_order!(cart)
        order = nil
        ApplicationRecord.transaction do
          order = cart.store.orders.new(
            cart: cart,
            status: 'draft',
            email: cart.email,
            currency: cart.currency,
            locale: cart.locale,
            market: cart.market,
            channel: cart.channel,
            company: cart.resolved_company,
            customer: cart.customer,
            token: cart.token,
            accept_marketing: cart.accept_marketing,
            coupon_code: cart.read_attribute(:coupon_code),
            preferred_stock_location_id: cart.preferred_stock_location_id,
            customer_note: cart.customer_note,
            po_number: cart.po_number,
            last_ip_address: cart.last_ip_address,
            ship_address: cart.ship_address&.snapshot,
            bill_address: cart.bill_address&.snapshot
          )
          order.save!

          line_item_map = copy_line_items!(cart, order)
          fulfillment_map = copy_fulfillments!(cart, order, line_item_map)
          copy_typed_lines!(cart, order, line_item_map, fulfillment_map)
          copy_promotions!(cart, order)
          copy_tax_identifier!(cart, order)
          copy_po_document!(cart, order)
          repoint_money_records!(cart, order)

          order.update_columns(
            item_total: cart.item_total,
            total_quantity: cart.total_quantity,
            adjustment_total: cart.adjustment_total,
            included_tax_total: cart.included_tax_total,
            additional_tax_total: cart.additional_tax_total,
            taxable_adjustment_total: cart.taxable_adjustment_total,
            non_taxable_adjustment_total: cart.non_taxable_adjustment_total,
            discount_total: cart.discount_total,
            fee_total: cart.fee_total,
            delivery_total: cart.delivery_total,
            total: cart.total,
            payment_total: cart.payment_total
          )
        end
        order
      end

      # Freezes the buyer's tax registration onto the order, stamped with which
      # link of the chain won. A copy rather than a reference: the customer can
      # change or withdraw the number later, and the placed order's tax still
      # has to be explainable. Consumer sales copy nothing.
      def copy_tax_identifier!(cart, order)
        resolved = cart.resolved_tax_identifier
        return if resolved.nil?

        attributes = resolved.attributes.except('id', 'owner_type', 'owner_id',
                                                'created_at', 'updated_at')
        order.create_tax_identifier!(attributes.merge('source' => source_of(resolved)))
      end

      # The buyer's purchase order follows the number onto the order. The same
      # blob is attached to both records rather than uploaded twice — the cart
      # keeps its copy so a completion that rolls back leaves the buyer's
      # upload where they left it.
      #
      # The order is persisted and unchanged here, so `attach` saves
      # immediately and answers nil instead of raising when the save is
      # refused. Left unchecked the placed order would simply have no
      # paperwork, silently — so the failure is raised into the completion
      # transaction rather than dropped.
      def copy_po_document!(cart, order)
        return unless cart.po_document.attached?

        return if order.po_document.attach(cart.po_document.blob)

        raise ActiveRecord::RecordInvalid, order
      end

      # Which link of the chain produced the snapshot, so a placed order's tax
      # treatment names its own reason.
      def source_of(resolved)
        case resolved.owner
        when Spree::Cart then 'override'
        when Spree::Company then 'company'
        else 'customer'
        end
      end

      # Copies carry skip_tax_estimation: the cart's tax rows are copied onto the
      # order a few lines below, so estimating per copied item would ask the
      # provider a question whose answer is discarded — and for an external
      # engine that is a billable remote call per line item, inside the
      # completion lock.
      def copy_line_items!(cart, order)
        cart.line_items.reload.index_with do |cart_line_item|
          attributes = cart_line_item.attributes.except('id', 'cart_id', 'created_at', 'updated_at')
          line_item = order.line_items.new(attributes.merge('order_id' => order.id))
          line_item.skip_tax_estimation = true
          line_item.save!
          line_item
        end
      end

      # @return [Hash{Integer => Integer}] cart fulfillment id → order fulfillment id
      def copy_fulfillments!(cart, order, line_item_map)
        line_item_id_map = line_item_map.transform_keys(&:id).transform_values(&:id)

        cart.fulfillments.reload.each_with_object({}) do |cart_fulfillment, map|
          attributes = cart_fulfillment.attributes.except('id', 'cart_id', 'number', 'created_at', 'updated_at')
          fulfillment = order.fulfillments.create!(attributes.merge('order_id' => order.id, 'address_id' => order.ship_address_id))

          if (selected = cart_fulfillment.selected_delivery_rate)
            rate_attributes = selected.attributes.except('id', 'created_at', 'updated_at')
            fulfillment.delivery_rates.create!(rate_attributes.merge('fulfillment_id' => fulfillment.id))
          end

          cart_fulfillment.fulfillment_items.each do |item|
            item_attributes = item.attributes.except('id', 'created_at', 'updated_at')
            fulfillment.fulfillment_items.create!(
              item_attributes.merge(
                'fulfillment_id' => fulfillment.id,
                'order_id' => order.id,
                'line_item_id' => line_item_id_map.fetch(item.line_item_id)
              )
            )
          end

          map[cart_fulfillment.id] = fulfillment.id
        end
      end

      # The cart's rows are the record of what the sale was costed at, so the
      # order receives them verbatim rather than being re-estimated.
      def copy_typed_lines!(cart, order, line_item_map, fulfillment_map)
        line_item_id_map = line_item_map.transform_keys(&:id).transform_values(&:id)

        [Spree::TaxLine, Spree::Discount, Spree::Fee].each do |klass|
          klass.where(cart_id: cart.id).find_each do |row|
            attributes = row.attributes.except('id', 'cart_id', 'created_at', 'updated_at')
            attributes['order_id'] = order.id

            if row.respond_to?(:line_item_id) && row.line_item_id
              attributes['line_item_id'] = line_item_id_map[row.line_item_id]
              next if attributes['line_item_id'].nil?
            end
            if row.respond_to?(:fulfillment_id) && row.fulfillment_id
              attributes['fulfillment_id'] = fulfillment_map[row.fulfillment_id]
              next if attributes['fulfillment_id'].nil?
            end

            klass.create!(attributes)
          end
        end
      end

      def copy_promotions!(cart, order)
        cart.order_promotions.find_each do |cart_promotion|
          order.order_promotions.find_or_create_by!(promotion_id: cart_promotion.promotion_id)
        end
      end

      def repoint_money_records!(cart, order)
        cart.payments.update_all(order_id: order.id, cart_id: nil)
        cart.payment_sessions.update_all(order_id: order.id, cart_id: nil)
        cart.stock_reservations.update_all(order_id: order.id, cart_id: nil)
        Spree::CouponCode.where(cart_id: cart.id).update_all(order_id: order.id, cart_id: nil)
        order.payments.reset
      end

      # Completion gates on "a valid payment exists covering the total",
      # never on paid? — a net-terms order completes with a pending payment.
      def payment_covered?(order)
        order.payments.reset
        order.payments.valid.where(status: %w[pending processing completed]).sum(:amount) >= order.total
      end

      # The FINALIZE phase: the order-side completion workflow owns the
      # placement side effects; the two cart-side stamps follow.
      #
      # A cart spanning several sellers divides here rather than earlier: the
      # customer authorised one amount against one basket, so the money is
      # taken first and the bookkeeping follows it. A crash between the two
      # resumes like any other finalize failure.
      def finalize!(cart, order)
        @order = order
        step :split_by_seller
        step :allocate_payment_splits
        step :complete_orders
        step :complete_cart
        step :mark_coupon_codes_used
        external_step :commit_tax
      end

      # Divides the paid draft order into one order per seller, under a group.
      # A cart of one partition — all first-party, or all one seller — is left
      # exactly as it is: no group, no splits, and the order it already built
      # is the order the customer gets.
      #
      # The draft order built in PREPARE becomes the group's first child rather
      # than being replaced. It is the record the payment was taken against and
      # the row carrying the unique cart_id that makes completion replayable,
      # so it is kept and narrowed to its own partition; the remaining
      # partitions become new siblings beside it.
      def split_by_seller
        @order_group = cart.order_group
        return if order_group.present?
        return if order.placed?

        partitions = Spree::Carts::PartitionBySeller.call(purchase: order).value

        if partitions.one?
          # Nothing to divide, but the sale still belongs to whoever made it:
          # a basket entirely from one seller is that seller's order, and the
          # column is what their own order list reads.
          order.update_columns(seller_id: partitions.first.seller_id) if order.seller_id != partitions.first.seller_id
          return
        end

        return if partitions.empty?

        result = Spree::Carts::SplitBySeller.call(cart: cart, order: order, partitions: partitions)
        failure(cart, code: 'split_failed', message: result.error) if result.failure?

        @order_group = result.value
        # Ordered, because which child comes first decides which one carries
        # the confirmation email — that must not depend on how the rows come
        # back.
        @order = order_group.orders.order(:id).first
      end

      def allocate_payment_splits
        return if order_group.nil?

        result = Spree::OrderGroups::AllocatePayments.call(group: order_group)
        failure(cart, code: 'split_failed', message: result.error) if result.failure?
      end

      # Places what the checkout produced — the children of a split, or the one
      # order otherwise. Each child publishes its own order.placed, which is
      # what gets every seller their own commission lines with no marketplace
      # code in the commission engine.
      #
      # A split checkout's payments were already taken against the whole basket
      # and moved onto the group, so the children place without processing them
      # again. One purchase means one confirmation email: the first child
      # carries the notification and its siblings place silently.
      def complete_orders
        split = order_group.present?

        placed_orders.each_with_index do |child, index|
          result = Spree.order_complete_workflow.call(
            order: child,
            payment_pending: split,
            notify_customer: split && !index.zero? ? false : nil
          )
          failure(cart, code: 'completion_failed', message: result.error) if result.failure?
        end

        order_group&.publish_event('order_group.completed')
      end

      # Tells the tax engine the sale is final. A no-op for the built-in
      # provider, whose rows are already the record; external engines file the
      # document that a tax return is later built from. Outside the
      # transaction — a remote call must not hold the completion open.
      #
      # Every order of a split checkout is filed, not just the first: each is a
      # separate sale with its own tax, and an unfiled sibling is a hole in the
      # merchant's return that only surfaces at filing time.
      def commit_tax
        placed_orders.each { |placed| placed.tax_provider.commit(placed) }
      end

      # What this checkout produced: the children of a split, or the one order
      # otherwise. The single answer to "which orders came out of here", so
      # placement and tax filing can never disagree about the set.
      def placed_orders
        order_group.present? ? order_group.orders.to_a : [order]
      end

      def complete_cart
        return if cart.completed?

        cart.update_columns(completed_at: Time.current, completing_at: nil)
      end

      def mark_coupon_codes_used
        Spree::CouponCode.where(order_id: order.id).unused.update_all(state: 1)
      end
    end
  end
end
