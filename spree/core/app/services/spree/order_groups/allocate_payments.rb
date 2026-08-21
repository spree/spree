module Spree
  module OrderGroups
    # Re-points a split checkout's payments onto the group and records each
    # child order's share of them.
    #
    # The customer authorised one amount for one basket, so the charge stays
    # singular and the per-seller figures are bookkeeping. Every payment on the
    # group gets its own set of shares — the card, the store credit, the gift
    # card — apportioned by what each child is worth, with largest-remainder so
    # a child's shares across all payments add back up to that child's total. A
    # mixed store-credit checkout therefore never overstates what the gateway is
    # exposed to on any one seller's order.
    #
    # Idempotent: the shares are found-or-created on the unique
    # (payment, order) index, so a replayed completion writes nothing new.
    class AllocatePayments
      prepend Spree::ServiceModule::Base

      # @param group [Spree::OrderGroup]
      # @return [Spree::ServiceModule::Result] value is the group
      def call(group:)
        orders = group.orders.order(:id).to_a
        return success(group) if orders.empty?

        ApplicationRecord.transaction do
          claim_payments(group)
          # What each child still needs covering. Payments draw this down as
          # they are allocated, so several payments cannot each round in the
          # same direction and leave one child a penny over and another under —
          # every child ends up with exactly its own total.
          outstanding = orders.map { |order| Spree::Money::Rounding.to_minor_units(order.total, group.currency) }

          group.payments.reload.each do |payment|
            taken = allocate(payment, orders, outstanding)
            outstanding = outstanding.each_with_index.map { |amount, index| amount - taken[index] }
          end
        end

        success(group)
      end

      private

      # The payments were made against the cart and re-pointed onto the child
      # orders as they were built; a split checkout moves them up to the group,
      # where the single charge actually belongs.
      #
      # Payment sessions deliberately stay where they are. A session is the
      # external gateway's own record of one authorisation attempt, keyed to
      # the reference the provider holds — moving it would fork a reference
      # that has to keep resolving, and nothing about the split changes what
      # the gateway authorised.
      def claim_payments(group)
        order_ids = group.orders.select(:id)
        Spree::Payment.where(order_id: order_ids).update_all(order_id: nil, order_group_id: group.id)
        group.payments.reset
      end

      # A share records what this order can draw on, and what it already has.
      #
      # The captured figure matters as much as the authorised one: a checkout
      # paid by a method that charges up front arrives here with the payment
      # already completed, and a share showing nothing captured would report
      # every child of a fully paid checkout as merely authorised. So a
      # completed payment's shares are born captured, and one still pending is
      # captured later, as each seller dispatches.
      #
      # @param outstanding [Array<Integer>] what each child still needs, in
      #   minor units, so this payment covers what is left rather than
      #   re-dividing the whole basket
      # @return [Array<Integer>] what each child took from this payment
      def allocate(payment, orders, outstanding)
        # A basket worth nothing — fully discounted, wholly gift-carded — has
        # nothing to divide by. Every child still gets a share saying so,
        # rather than none at all, so each reads as settled instead of waiting
        # on money that was never owed.
        weights = outstanding.sum.positive? ? outstanding : Array.new(orders.size, 1)

        currency = payment.currency
        shares = Spree::Adjusters::LargestRemainder.largest_remainder_shares(
          Spree::Money::Rounding.to_minor_units(payment.amount, currency), weights
        )
        captured = payment.completed?

        orders.each_with_index do |order, index|
          split = Spree::PaymentSplit.find_or_initialize_by(payment_id: payment.id, order_id: order.id)
          next if split.persisted?

          share = Spree::Money::Rounding.from_minor_units(shares[index], currency)
          split.currency = payment.currency
          split.authorized_amount = share
          split.captured_amount = captured ? share : 0
          split.save!
        end

        shares
      end

    end
  end
end
