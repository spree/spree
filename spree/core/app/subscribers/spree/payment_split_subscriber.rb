# frozen_string_literal: true

module Spree
  # Keeps a split checkout's per-order shares in step with the money.
  #
  # Two things move a share after it is written. A refund puts one seller's
  # order right, and must touch only that order's share: the customer's money
  # comes back out of the one charge either way, but what each seller owes and
  # is owed does not move because a sibling refunded. And a payment completing
  # captures the whole basket at once — an authorisation settled after
  # placement — which every child shares in proportionally.
  #
  # Synchronous, like the commission subscriber, because a share is what an
  # order's payment status is derived from: an order that still read as
  # unpaid until a job ran would be showing the wrong thing to the merchant
  # and to the seller.
  #
  # A share's refunded amount moves when a refund completes (payment.refunded,
  # whether the provider answered at once or by webhook) or fails after it
  # completed (refund.failed), never when the row is created: a provider may
  # still refuse a requested refund.
  class PaymentSplitSubscriber < Spree::Subscriber
    subscribes_to 'payment.refunded', 'refund.failed', 'payment.completed', async: false

    on 'payment.refunded', :handle_refund
    on 'refund.failed', :handle_refund_failed
    on 'payment.completed', :handle_capture

    # The payload names the payment, not the refund, so every share of it is
    # recomputed; each is derived from the rows, so the others do not move.
    def handle_refund(event)
      payment = Spree::Payment.find_by_prefix_id(event.payload['id'])
      return if payment.nil? || !payment.grouped?

      payment.payment_splits.includes(:order).find_each { |split| refresh_refunded_amount(split) }
    end

    def handle_refund_failed(event)
      refund = Spree::Refund.find_by_prefix_id(event.payload['id'])
      order = refund&.order
      return if order.nil? || !order.grouped?

      split = order.payment_split_for(refund.payment)
      refresh_refunded_amount(split) if split
    end

    # The whole payment settled, so every share it covers is captured in full.
    # A share already carrying a larger captured figure is left alone — a
    # dispatch captured it first, and that is the more specific record.
    def handle_capture(event)
      payment = Spree::Payment.find_by_prefix_id(event.payload['id'])
      return if payment.nil? || !payment.grouped?

      payment.payment_splits.includes(:order).each do |split|
        # Read and written under the row's lock, so a dispatch capturing the
        # same share at the same moment cannot be overwritten by the figure
        # this one read before it.
        settled = with_share_lock(split) do
          next false if split.captured_amount >= split.authorized_amount

          split.update!(captured_amount: split.authorized_amount)
          true
        end

        Spree::Orders::UpdateStatuses.call(order: split.order) if settled && split.order
      end
    end

    private

    def refresh_refunded_amount(split)
      order = split.order
      # Recomputed from the completed refunds rather than incremented, so a
      # replayed event cannot count the same money twice — and read and
      # written under the row's lock, so two refunds landing together cannot
      # each total the rows before the other's has committed.
      with_share_lock(split) do
        refunded = Spree::Refund.completed_or_unset.where(payment_id: split.payment_id, order_id: split.order_id).sum(:amount)
        split.update!(refunded_amount: refunded)
      end

      # Deliberately re-derived here even though OrderStatusSubscriber also
      # answers these events: subscriber order is not guaranteed, and a status
      # derived before this share was written would describe the refund as
      # not having happened.
      Spree::Orders::UpdateStatuses.call(order: order) if order
    end

    # Locks the share's order before the share. Saving a share writes its
    # order's payment total, and payment settlement locks orders before the
    # payment and its shares, so taking the share first could deadlock
    # against a settlement of the same payment.
    def with_share_lock(split, &block)
      ApplicationRecord.transaction do
        Spree::Order.lock.find_by(id: split.order_id)
        split.with_lock(&block)
      end
    end
  end
end
