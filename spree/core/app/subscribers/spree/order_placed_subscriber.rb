module Spree
  # Completion side effects decoupled from Order#finalize! — each guards
  # its own idempotency. Runs synchronously on order.placed.
  class OrderPlacedSubscriber < Spree::Subscriber
    subscribes_to 'order.placed', async: false

    def handle(event)
      order = Spree::Order.find_by_prefix_id(event.payload['id'])
      return unless order

      subscribe_to_newsletter(order)
      create_user_record(order)
      order.consider_risk
    end

    private

    def subscribe_to_newsletter(order)
      return unless order.accept_marketing?

      Spree::NewsletterSubscriber.subscribe(email: order.email, user: order.user, store: order.store)
    end

    def create_user_record(order)
      return if order.user.present?
      return unless order.signup_for_an_account?

      Spree::Orders::CreateUserAccount.call(order: order, accepts_email_marketing: order.accept_marketing?)
    end
  end
end
