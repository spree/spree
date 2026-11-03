module Spree
  # Issues the gift cards an order bought once it is paid: at placement when
  # checkout already took the money, otherwise when the payment settles.
  class GiftCardIssuanceSubscriber < Spree::Subscriber
    subscribes_to 'order.placed', 'order.paid'

    def handle(event)
      order = Spree::Order.find_by_prefix_id(event.payload['id'])
      return unless order

      Spree.gift_card_issue_from_order_workflow.call(order: order, paid: event.name == 'order.paid')
    end
  end
end
