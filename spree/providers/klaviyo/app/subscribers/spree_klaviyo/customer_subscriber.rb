module SpreeKlaviyo
  # Keeps a customer's Klaviyo profile current.
  class CustomerSubscriber < Spree::Subscriber
    subscribes_to 'user.created', 'user.updated'

    def handle(event)
      # Customers belong to every store, so the store is the one the event names.
      integration = Spree::Integrations::Klaviyo.active_for(event.store)
      return unless integration

      customer = Spree.customer_class.find_by_prefix_id(event.payload['id'])
      return unless customer

      SpreeKlaviyo::SyncProfileJob.perform_later(integration, customer)
    end
  end
end
