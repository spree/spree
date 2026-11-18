module SpreeAdyen
  # Captures, once the order is placed, the payments Adyen holds for a capture
  # request (Klarna, Riverty, Affirm) on a method that captures at checkout:
  # Adyen keeps those authorised whatever the account's capture delay says, so
  # Spree asks, and the payment waits for Adyen's CAPTURE as any capture does.
  class CaptureHeldPaymentsSubscriber < Spree::Subscriber
    subscribes_to 'order.placed'

    def handle(event)
      order = Spree::Order.find_by_prefix_id(event.payload['id'])
      return if order.nil?

      order.settlement_payments.with_status(:pending).includes(:payment_method).find_each do |payment|
        next unless held_for_capture?(payment)

        # A payment already claimed by another capture is refused by the
        # workflow's own claim, so a redelivered event captures nothing twice.
        Spree.payment_capture_workflow.call(payment: payment)
      end
    end

    private

    def held_for_capture?(payment)
      payment.payment_method.is_a?(SpreeAdyen::Gateway) &&
        payment.payment_method.capture_at_checkout? &&
        SpreeAdyen::Variants.held_for_capture?(payment.metadata['adyen_variant'])
    end
  end
end
