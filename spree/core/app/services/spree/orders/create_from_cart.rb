module Spree
  module Orders
    # Copies a cart into a fresh draft order, leaving the cart untouched.
    # Not the completion copier: no money records are re-pointed and the
    # one-shot +cart_id+ slot stays free.
    class CreateFromCart
      prepend Spree::ServiceModule::Base

      # Money/tax columns stay behind — the draft recalculates its own.
      LINE_ITEM_COPIED_ATTRIBUTES = %w[
        variant_id quantity price currency cost_price
        price_list_id price_source tax_category_id metadata
      ].freeze

      # @param cart [Spree::Cart]
      # @param created_by [Object, nil] the staff member starting the draft
      #   (Spree.admin_user_class instance); nil when buyer-initiated
      # @param customer [Object, nil] overrides the cart's customer
      # @return [Spree::ServiceModule::Result] value is the draft Spree::Order
      def call(cart:, created_by: nil, customer: nil)
        return failure(:cart_is_required) if cart.nil?

        order = nil
        ApplicationRecord.transaction do
          order = build_order(cart, customer: customer, created_by: created_by)
          order.save!

          copy_line_items(cart, order)
          estimate_taxes(order)
          build_fulfillments(order)
          order.recalculate_totals!
        end

        success(order.reload)
      rescue ActiveRecord::RecordInvalid => e
        failure(e.record, e.record.errors.full_messages.to_sentence)
      end

      private

      def build_order(cart, customer:, created_by:)
        resolved_customer = customer || cart.customer

        cart.store.orders.new(
          status: 'draft',
          created_by: created_by,
          customer: resolved_customer,
          email: resolved_customer&.email || cart.email,
          currency: cart.currency,
          locale: cart.locale,
          market: cart.market,
          channel: cart.channel,
          company: cart.resolved_company,
          customer_note: cart.customer_note,
          metadata: cart.metadata.to_h,
          preferred_stock_location_id: cart.preferred_stock_location_id,
          token: Spree::GenerateToken.new.call(Spree::Order),
          ship_address: cart.ship_address&.snapshot,
          bill_address: cart.bill_address&.snapshot
        )
      end

      def copy_line_items(cart, order)
        cart.line_items.each do |cart_line_item|
          line_item = order.line_items.new(cart_line_item.attributes.slice(*LINE_ITEM_COPIED_ATTRIBUTES))
          # Estimated once for the batch below, not once per line.
          line_item.skip_tax_estimation = true
          line_item.save!
        end
      end

      def estimate_taxes(order)
        line_items = order.line_items.reload
        return if line_items.empty?

        order.tax_provider.estimate(order, line_items, **order.tax_estimate_inputs)
      end

      def build_fulfillments(order)
        result = Spree::Orders::BuildFulfillments.call(order: order)
        return if result.success?

        order.errors.add(:base, result.error.to_s.presence || 'Failed to build shipments')
        raise ActiveRecord::RecordInvalid, order
      end
    end
  end
end
