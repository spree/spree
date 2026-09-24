module Spree
  # The trigger side of derive-then-persist statuses: any payment, refund,
  # store credit, fulfillment or return change recomputes the owning order's
  # payment_status / fulfillment_status through the single writer
  # (Spree::Orders::UpdateStatuses). Synchronous so API responses right
  # after a capture/void/fulfill already carry the fresh status. Cart-owned
  # records are skipped — carts have no status columns.
  #
  # Money-moving payment events additionally re-sum payment_total through
  # the totals workflow, which is the only writer of that column. A payment
  # save used to do both itself in an after_save callback; the callback and
  # these events overlapped, so one capture recomputed the order four
  # times.
  class OrderStatusSubscriber < Spree::Subscriber
    subscribes_to 'payment.created', 'payment.updated', 'payment.deleted',
                  'payment.completed', 'payment.captured', 'payment.voided',
                  'refund.created', 'refund.updated',
                  'store_credit.created', 'store_credit.updated', 'store_credit.deleted',
                  'fulfillment.created', 'fulfillment.updated', 'fulfillment.deleted',
                  'return.received', 'return.refunded', 'return.canceled',
                  async: false

    # Events whose payload changes what the customer has actually paid, so
    # payment_total has to be re-summed before statuses derive from it.
    # Store credit is not one of them: the money stayed with the store, and
    # payment_total is what came in through payments.
    MONEY_EVENTS = %w[
      payment.created payment.updated payment.deleted payment.completed
      payment.voided refund.created refund.updated
      return.refunded
    ].freeze

    # payment.captured always accompanies payment.completed for the same
    # settlement — the order changed once, so it is answered once. The
    # remaining overlap (payment.updated is the settling save's own
    # after_commit) is left alone deliberately: the payload cannot tell an
    # accompanying update from a genuine later edit of a completed payment,
    # and skipping the wrong one would leave the order stale. Two cheap
    # recomputations beat a missed one.
    #
    # Keyed on the event, never on the order: two payments settling in one
    # request (mixed tender) are two real settlements and must both count.
    SETTLEMENT_COMPANIONS = %w[payment.captured].freeze

    def handle(event)
      return if event.name.in?(SETTLEMENT_COMPANIONS)

      owner = owner_for(event)
      return if owner.nil?

      # Only the payment side is re-summed, before statuses derive from it
      # (payment_status reads payment_total). Deliberately not the full
      # totals workflow: a payment settling must not re-derive item and
      # delivery money, which is the totals workflow's business and would
      # overwrite figures the caller set.
      owner.refresh_payment_total! if event.name.in?(MONEY_EVENTS) && owner.respond_to?(:refresh_payment_total!)

      # Carts carry payment_total but no status columns — money still has to
      # be right while checkout is in flight, statuses only exist on orders.
      owner.update_statuses! if owner.is_a?(Spree::Order)
    end

    private

    def owner_for(event)
      resource_class = {
        'payment' => Spree::Payment,
        'refund' => Spree::Refund,
        'store_credit' => Spree::StoreCredit,
        'fulfillment' => Spree::Fulfillment,
        'return' => Spree::Return
      }[event.resource_type]
      return if resource_class.nil?

      # A paranoid model's .deleted event leaves the row in place but out of
      # default scope, and a credit that has been withdrawn is exactly the
      # kind of change the order has to learn about.
      record = (resource_class.try(:with_deleted) || resource_class).
               find_by_prefix_id(event.payload['id'])
      # Neither Payment nor Fulfillment is paranoid, so their .deleted events
      # arrive with the row already gone and a payload carrying no owner —
      # nothing can lead back to the order. The models whose deletion changes
      # order money recalculate from their own after_destroy instead.
      return if record.nil?

      record.try(:owner) || record.try(:order) || record.try(:refunded_order) ||
        record.try(:payment)&.try(:owner)
    end
  end
end
