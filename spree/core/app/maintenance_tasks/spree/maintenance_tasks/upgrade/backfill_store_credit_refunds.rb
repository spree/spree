module Spree
  module MaintenanceTasks
    module Upgrade
      # Store credit given back for an order is now recorded as refunds against
      # the order's payments, the way a refund to the card is. Credit issued
      # before then names its order (`refunded_order`) but has no refund rows,
      # so nothing would stop a later card refund or cancellation from giving
      # the same money back again. This writes the missing rows, oldest payment
      # first, as the refund workflows do.
      #
      # The rows record money that already went back, so no events are
      # published: nothing is sent to a gateway, a webhook or a seller's
      # earnings. A credit larger than what its order's payments can still
      # refund is recorded as far as they allow and counted under
      # `credits_partly_unallocated` for the operator to review.
      class BackfillStoreCreditRefunds < Spree::MaintenanceTask
        supports_dry_run
        collection_batch_size 500

        def collection
          Spree::StoreCredit.
            where.not(refunded_order_id: nil).
            where.not(id: Spree::Refund.to_store_credit.select(:store_credit_id)).
            order(:id)
        end

        def process(credit)
          order = credit.refunded_order
          return tally(:credits_without_order) if order.nil?

          unallocated = Spree::Events.disable do
            ApplicationRecord.transaction do
              Spree::Order.lock.find(order.id) unless dry_run?
              record_refunds(credit, order)
            end
          end
          tally(dry_run? ? :credits_partly_unallocatable : :credits_partly_unallocated) if unallocated.positive?

          return tally(:credits_would_backfill) if dry_run?

          tally(:credits_backfilled)
          refresh_order(order)
        end

        private

        # @return [BigDecimal] what could not be recorded against any payment
        def record_refunds(credit, order)
          remaining = credit.amount.to_d
          reason = Spree::RefundReason.return_processing_reason(order.store) unless dry_run?

          refundable_shares(order).each do |payment, refundable|
            break unless remaining.positive?

            amount = [refundable, remaining].min
            next unless amount.positive?

            write_refund(credit, order, payment, amount, reason) unless dry_run?
            remaining -= amount
          end

          remaining
        end

        def write_refund(credit, order, payment, amount, reason)
          payment.refunds.create!(
            status: 'completed',
            transaction_id: credit.prefixed_id,
            store_credit: credit,
            amount: amount,
            order: order,
            reason: reason,
            originator: (credit.originator if Spree::Refund.returned_item_originators.include?(credit.originator_type)),
            created_at: credit.created_at
          )
        end

        # What each completed payment can still give back to this order:
        # the payment's own balance, or on a split checkout this order's share.
        #
        # @return [Hash{Spree::Payment => BigDecimal}]
        def refundable_shares(order)
          return order.payments.completed.order(:created_at).index_with { |payment| payment.credit_allowed.to_d } unless order.grouped?

          order.payment_splits.includes(:payment).order(:created_at).each_with_object({}) do |split, shares|
            shares[split.payment] = split.refundable_amount if split.payment&.completed?
          end
        end

        # Re-derives what the events would have: each share's refunded figure,
        # the order's payment total and its statuses.
        def refresh_order(order)
          order.payment_splits.each do |split|
            refunded = Spree::Refund.completed_or_unset.where(payment_id: split.payment_id, order_id: order.id).sum(:amount)
            split.update!(refunded_amount: refunded)
          end
          order.refresh_payment_total!
          order.update_statuses!
        end
      end
    end
  end
end
