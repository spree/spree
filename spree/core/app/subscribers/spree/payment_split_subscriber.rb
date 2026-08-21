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
  class PaymentSplitSubscriber < Spree::Subscriber
    subscribes_to 'refund.created', 'payment.completed', async: false

    on 'refund.created', :handle_refund
    on 'payment.completed', :handle_capture

    def handle_refund(event)
      refund = Spree::Refund.find_by_prefix_id(event.payload['id'])
      return unless refund

      order = refund.order
      return if order.nil? || !order.grouped?

      split = order.payment_split_for(refund.payment)
      return if split.nil?

      # Recomputed from the refunds rather than incremented, so a replayed
      # event cannot count the same money twice — and read and written under
      # the row's lock, so two refunds landing together cannot each total the
      # rows before the other's has committed.
      split.with_lock do
        refunded = Spree::Refund.where(payment_id: refund.payment_id, order_id: order.id).sum(:amount)
        split.update!(refunded_amount: refunded)
      end

      # Deliberately re-derived here even though OrderStatusSubscriber also
      # answers refund.created: subscriber order is not guaranteed, and a
      # status derived before this share was written would describe the refund
      # as not having happened.
      Spree::Orders::UpdateStatuses.call(order: order)
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
        settled = split.with_lock do
          next false if split.captured_amount >= split.authorized_amount

          split.update!(captured_amount: split.authorized_amount)
          true
        end

        Spree::Orders::UpdateStatuses.call(order: split.order) if settled && split.order
      end
    end
  end
end
