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
      COMPLETING_TTL = 5.minutes

      hooks :validate, :before_finalize, :after_finalize

      # Hook handlers read this plus the argument readers.
      attr_reader :order

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
        success(order)
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
        order = completion_result(cart)
        return if order.nil?

        halt!(order) if order.canceled?

        if !order.placed? && order.payment_required? && !payment_covered?(order)
          failure(cart, code: 'payment_failed', message: Spree.t(:payment_processing_failed))
        end

        finalize!(cart, order)
        halt!(order)
      end

      def guard_concurrent_completion
        failure(cart, code: 'completion_in_progress') if cart.completing? && cart.completing_at > COMPLETING_TTL.ago
      end

      # In-lock recalculation — the totals about to be charged are computed
      # here, not trusted from earlier requests.
      def recalculate_in_lock
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

      # Exactly one of cart.order (single partition) or, later, the
      # multi-vendor order group.
      def completion_result(cart)
        cart.order
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
            customer: cart.customer,
            token: cart.token,
            accept_marketing: cart.accept_marketing,
            coupon_code: cart.read_attribute(:coupon_code),
            preferred_stock_location_id: cart.preferred_stock_location_id,
            customer_note: cart.customer_note,
            last_ip_address: cart.last_ip_address,
            ship_address: cart.ship_address&.dup,
            bill_address: cart.bill_address&.dup
          )
          order.save!

          line_item_map = copy_line_items!(cart, order)
          fulfillment_map = copy_fulfillments!(cart, order, line_item_map)
          copy_typed_lines!(cart, order, line_item_map, fulfillment_map)
          copy_promotions!(cart, order)
          copy_tax_identifier!(cart, order)
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

        attributes = resolved.attributes.except('id', 'customer_id', 'cart_id', 'created_at', 'updated_at')
        order.create_tax_identifier!(
          attributes.merge('source' => resolved.cart_id.present? ? 'override' : 'customer')
        )
      end

      def copy_line_items!(cart, order)
        cart.line_items.reload.index_with do |cart_line_item|
          attributes = cart_line_item.attributes.except('id', 'cart_id', 'created_at', 'updated_at')
          order.line_items.create!(attributes.merge('order_id' => order.id))
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
        order.payments.valid.where(state: %w[pending processing completed]).sum(:amount) >= order.total
      end

      # The FINALIZE phase: the order-side completion workflow owns the
      # placement side effects; the two cart-side stamps follow.
      def finalize!(cart, order)
        @order = order
        step :complete_order, with: -> { Spree.order_complete_workflow }
        step :complete_cart
        step :mark_coupon_codes_used
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
