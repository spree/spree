module SpreeStripe
  # Keeps the Stripe customer in sync with the Spree one.
  #
  # Lifecycle events carry no changed-attribute information, so this fires on
  # every customer update rather than only on name, email or address changes.
  # UpdateCustomer returns immediately for a customer with no Stripe customers,
  # which is the common case and costs one indexed query.
  class CustomerUpdatedSubscriber < Spree::Subscriber
    subscribes_to 'user.updated'

    def handle(event)
      customer = Spree.customer_class.find_by_prefix_id(event.payload['id'])
      return if customer.blank?

      SpreeStripe::UpdateCustomer.new.call(customer: customer)
    end
  end
end
