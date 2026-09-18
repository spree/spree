module Spree
  module Orders
    # The order-side completion workflow — the ONE home for everything that
    # happens when an order becomes placed. Serves both entry points:
    # checkout ({Spree::Carts::Complete} delegates its FINALIZE phase here
    # with payments already captured) and admin/B2B draft completion (which
    # may still need to process payments). Idempotent: an already-placed
    # order halts successfully, so interrupted completions replay safely.
    class Complete < Spree::Workflow
      # Set only when the order divided between sellers.
      attr_reader :order_group

      # @param order [Spree::Order]
      # @param payment_pending [Boolean] when true the order places without
      #   processing payments (B2B / invoice-later). With no payment rows the
      #   status rollup yields payment_status: 'none' — whether an unpaid
      #   placed order deserves a distinct value is the wholesale-deposit
      #   rollup work's call (docs/plans/6.0-b2b-wholesale-shipping.md phase 7)
      # @param notify_customer [Boolean, nil] admin drafts pass false to
      #   complete silently; nil (checkout) leaves customer notification on
      # @param attribute_seller [Boolean] false when the caller has already
      #   filed the sale under its seller — the checkout does it before placing
      #   its children, and partitioning again would re-read every line item
      # @return [Spree::ServiceModule::Result] value is the order, or the
      #   Spree::OrderGroup when it divided between sellers
      def perform(order:, payment_pending: false, notify_customer: nil, attribute_seller: true)
        super

        order.notify_customer = notify_customer unless notify_customer.nil?

        # Replaying finishes what an interrupted division started — a sibling
        # left in draft is an order nobody will ever ship — and answers with
        # what the first run produced, rather than reporting one seller's order
        # where it first reported the whole purchase.
        if order.completed?
          @order_group = order.order_group
          step :complete_sibling_orders
          halt!(order_group || order)
        end

        step :ensure_not_canceled

        order.with_lock do
          unless order.reload.placed?
            step :process_payments unless payment_pending || !order.payment_required?
            step :split_by_seller
            step :finalize_fulfillments
            step :place_order
            step :use_coupon_codes
            step :redeem_gift_card
            step :fulfill_auto_fulfillments
            step :ensure_digital_links
          end
        end

        step :ensure_placed_status
        step :release_stock_reservations
        step :update_statuses
        step :publish_order_placed
        step :complete_sibling_orders

        success(order_group || order)
      end

      private

      def ensure_not_canceled
        failure(order, 'Order is canceled') if order.canceled?
      end

      def process_payments
        order.process_payments! unless payment_covered?

        failure(order, order.errors.full_messages.to_sentence) if order.errors.any?
        failure(order, Spree.t(:payment_processing_failed)) unless payment_covered?
      end

      # Runs after payment so the money is settled once against the whole
      # basket, as the checkout does it, and before placement so each seller's
      # order is placed in its own right.
      def split_by_seller
        return unless attribute_seller
        # A checkout child arrives already divided.
        return if order.order_group_id.present?

        result = Spree::Orders::AttributeToSeller.call(order: order)
        failure(order, result.error) if result.failure?

        # The division adopts this very order as the group's first child and
        # reloads it, so it is already narrowed to its own seller's rows — and
        # it stays the row this workflow locked, and the object carrying the
        # caller's notify_customer, which a freshly loaded one would not.
        @order_group = result.value
      end

      # Typed adjustment rows are frozen once completed — the totals
      # recalculation only re-sums them, never regenerates (see
      # Spree::Carts::RecalculateTotals) — so no per-row locking is needed.
      #
      # Placement promises stock rather than moving it: an `allocated`
      # movement per fulfillment raises the level's allocated count and leaves
      # the shelf alone until the parcel actually leaves. Draft orders enter
      # here directly, which is why the write lives in this workflow.
      def finalize_fulfillments
        order.fulfillments.each do |fulfillment|
          fulfillment.finalize!
          allocate_fulfillment_stock(fulfillment)
        end
      end

      def allocate_fulfillment_stock(fulfillment)
        fulfillment.manifest.each do |item|
          next unless item.variant.track_inventory?
          next unless item.quantity.positive?

          fulfillment.stock_location.allocate(item.variant, item.quantity, fulfillment)
        end
      end

      def place_order
        order.update!(status: 'placed', completed_at: Time.current)
      end

      def use_coupon_codes
        Spree::CouponCodes::CouponCodesHandler.new(order: order).use_all_codes
      end

      # A refused redemption does not fail the order: the card was already
      # drawn down when it was applied, and the customer's order is placed.
      # It is reported rather than swallowed, because a card that cannot be
      # marked spent is a discrepancy someone has to look at.
      def redeem_gift_card
        return if order.gift_card.nil?

        result = Spree.gift_card_redeem_workflow.call(gift_card: order.gift_card)
        return if result.success?

        Rails.error.report(
          Spree::Core::GatewayError.new("Gift card #{order.gift_card.id} could not be redeemed: #{result.error}"),
          handled: true,
          context: { order_id: order.id, gift_card_id: order.gift_card.id },
          source: 'spree.core'
        )
      end

      # Providers that opt into auto_fulfill? (digital delivery today) get
      # forced to ready and fulfilled through the machine so all hooks
      # (links, events, webhooks) run.
      def fulfill_auto_fulfillments
        @auto_fulfilled_line_item_ids = []

        order.fulfillments.reload.each do |fulfillment|
          next unless fulfillment.provider.auto_fulfill?
          next if fulfillment.fulfilled? || fulfillment.canceled?

          # Digital goods go out the moment the order is placed; the payment
          # gate does not apply, hence force.
          Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment, force: true)
          @auto_fulfilled_line_item_ids.concat(fulfillment.line_items.map(&:id))
        end
      end

      # Digital links for items delivered by non-digital providers (physical
      # + download combos) — links are a digital-domain concern regardless of
      # the carrier; idempotent per quantity. Runs before the confirmation
      # email subscriber reads the links.
      def ensure_digital_links
        return unless order.with_digital_assets?

        provider = Spree::FulfillmentProvider::Digital.new
        order.digital_line_items.where.not(id: @auto_fulfilled_line_item_ids).includes(variant: :digital_assets).each do |line_item|
          provider.ensure_links_for(line_item)
        end
      end

      # Belt-and-braces for a completion interrupted between save and commit
      # in an earlier attempt.
      def ensure_placed_status
        order.update_columns(status: 'placed') unless order.reload.placed?
      end

      def release_stock_reservations
        Spree::StockReservations::Release.call(owner: order)
      end

      def update_statuses
        Spree::Orders::UpdateStatuses.call(order: order)
      end

      # The customer-facing side effects (newsletter, account creation, risk)
      # live in Spree::OrderPlacedSubscriber, triggered by this event.
      # order.completed is a one-release alias for 5.x webhook consumers;
      # wildcard subscribers dedupe on the metadata marker.
      def publish_order_placed
        payload = order.event_payload.merge(notify_customer: order.notify_customer)
        order.publish_event('order.placed', payload)
        order.publish_event('order.completed', payload, { deprecated_alias_of: 'order.placed' })
      end

      # Places the orders the division produced beside this one.
      #
      # They place without processing payments, because the money was taken
      # against the whole basket before the division and the group now holds
      # it, and silently, because one purchase means one confirmation email.
      # Only the ones still in draft, so a replay finishes an interrupted
      # division instead of re-placing what already went out.
      def complete_sibling_orders
        return if order_group.nil?

        pending = order_group.orders.where.not(id: order.id).where(status: 'draft').order(:id)
        return if pending.empty?

        pending.each { |sibling| place_sibling(sibling) }

        order_group.publish_event('order_group.completed')
      end

      def place_sibling(sibling)
        result = Spree.order_complete_workflow.call(order: sibling, payment_pending: true, notify_customer: false)
        failure(order, result.error) if result.failure?
      end

      def payment_covered?
        order.payments.reset
        order.payments.valid.where(status: %w[pending processing completed]).sum(:amount) >= order.amount_due_at_checkout
      end
    end
  end
end
