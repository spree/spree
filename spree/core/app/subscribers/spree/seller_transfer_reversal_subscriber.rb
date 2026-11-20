# frozen_string_literal: true

module Spree
  # Takes back part of a seller's earning when their order is refunded.
  #
  # Hangs off refunds rather than off returns, exchanges or claims
  # individually: every one of those funnels its money movement through a
  # refund, so one listener covers all three.
  #
  # Only money that went back is taken from the seller. A refund whose
  # provider answers later is created requested, so it is reversed when it
  # completes: payment.refunded names that refund in its metadata. The
  # workflow is keyed on the refund, so hearing a refund twice reverses it once.
  #
  # A refund on an order that never shipped reverses nothing, because nothing
  # was credited — the workflow answers that case by doing nothing rather than
  # by failing.
  class SellerTransferReversalSubscriber < Spree::Subscriber
    subscribes_to 'refund.created', 'payment.refunded'

    def handle(event)
      refunds_for(event).each do |refund|
        order = refund.order
        next if order.nil? || order.seller_id.blank?

        Spree.seller_transfer_reverse_workflow.call(order: order, amount: refund.amount, refund: refund)
      end
    end

    private

    def refunds_for(event)
      refund_id = event.name == 'payment.refunded' ? event.metadata['refund_id'] : event.payload['id']
      refund = Spree::Refund.find_by_prefix_id(refund_id) if refund_id.present?
      refund&.completed? ? [refund] : []
    end
  end
end
