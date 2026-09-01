# frozen_string_literal: true

module Spree
  # Takes back part of a seller's earning when their order is refunded.
  #
  # Hangs off `refund.created` rather than off returns, exchanges or claims
  # individually: every one of those funnels its money movement through a
  # refund, so one listener covers all three.
  #
  # A refund on an order that never shipped reverses nothing, because nothing
  # was credited — the workflow answers that case by doing nothing rather than
  # by failing.
  class SellerTransferReversalSubscriber < Spree::Subscriber
    subscribes_to 'refund.created'

    def handle(event)
      refund = Spree::Refund.find_by_prefix_id(event.payload['id'])
      return unless refund

      order = refund.order
      return if order.nil? || order.seller_id.blank?

      Spree.seller_transfer_reverse_workflow.call(order: order, amount: refund.amount, refund: refund)
    end
  end
end
