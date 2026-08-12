module Spree
  # The trigger side of derive-then-persist statuses: any payment, refund,
  # fulfillment or return change recomputes the owning order's
  # payment_status / fulfillment_status through the single writer
  # (Spree::Orders::UpdateStatuses). Synchronous so API responses right
  # after a capture/void/fulfill already carry the fresh status. Cart-owned
  # records are skipped — carts have no status columns.
  class OrderStatusSubscriber < Spree::Subscriber
    subscribes_to 'payment.created', 'payment.updated', 'payment.deleted',
                  'payment.completed', 'payment.captured', 'payment.voided',
                  'refund.created', 'refund.updated',
                  'fulfillment.created', 'fulfillment.updated', 'fulfillment.deleted',
                  'return.received', 'return.refunded', 'return.canceled',
                  async: false

    def handle(event)
      order = order_for(event)
      return unless order

      order.update_statuses!
    end

    private

    def order_for(event)
      resource_class = {
        'payment' => Spree::Payment,
        'refund' => Spree::Refund,
        'fulfillment' => Spree::Fulfillment,
        'return' => Spree::Return
      }[event.resource_type]
      return if resource_class.nil?

      record = resource_class.find_by_prefix_id(event.payload['id'])
      # Deleted records are gone by the time the event lands — nothing to
      # resolve; the deletion flows that matter (fulfillment rebuilds) run
      # their own recalculation.
      return if record.nil?

      owner = record.try(:owner) || record.try(:order) ||
              record.try(:payment)&.try(:owner)
      owner.is_a?(Spree::Order) ? owner : nil
    end
  end
end
