# frozen_string_literal: true

module Spree
  # Charges commission once an order is placed.
  #
  # Synchronous, like the other placement side effects, because the commission
  # lines are what a seller is told they owe: a marketplace that showed an
  # order before its commission existed would be showing an incomplete book,
  # and the work is a handful of rows against already-loaded records.
  #
  # Idempotency is the service's own — an order that already carries commission
  # is left alone — so a replayed event cannot charge a seller twice.
  class OrderCommissionSubscriber < Spree::Subscriber
    subscribes_to 'order.placed', async: false

    def handle(event)
      order = Spree::Order.find_by_prefix_id(event.payload['id'])
      return unless order

      Spree.commissions_commission_order_service.call(order: order)
    end
  end
end
