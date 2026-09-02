module Spree
  # Completion side effects decoupled from Order#finalize! — each guards
  # its own idempotency. Runs synchronously on order.placed.
  class OrderPlacedSubscriber < Spree::Subscriber
    subscribes_to 'order.placed', async: false

    def handle(event)
      order = Spree::Order.find_by_prefix_id(event.payload['id'])
      return unless order

      record_marketing_consent(order)
      subscribe_to_newsletter(order)
      create_user_record(order)
      order.consider_risk
    end

    private

    # An opt-in taken at checkout is consent, and GDPR Art. 7(1) asks the
    # controller to be able to demonstrate it. Recorded against the order
    # rather than the customer because guest checkout produces consent with no
    # account behind it — and the order is what the shop can point at.
    #
    # Only an opt-in is recorded: an unticked box is the absence of consent,
    # not its refusal, and storing it as a decision would misrepresent what
    # the buyer did.
    def record_marketing_consent(order)
      return unless order.accept_marketing?

      Spree::ConsentRecord.record!(
        store: order.store,
        owner: order,
        purpose: Spree::ConsentRecord::EMAIL_MARKETING,
        source: 'checkout',
        email: order.email,
        ip_address: order.last_ip_address
      )
    end

    def subscribe_to_newsletter(order)
      return unless order.accept_marketing?

      Spree::NewsletterSubscriber.subscribe(email: order.email, customer: order.customer, store: order.store)
    end

    def create_user_record(order)
      return if order.customer.present?
      return unless order.signup_for_an_account?

      Spree.customer_create_workflow.call(store: order.store, order: order)
    end
  end
end
