module SpreeKlaviyo
  # Sends Fulfilled Order for each package shipped.
  class FulfillmentSubscriber < Spree::Subscriber
    subscribes_to 'fulfillment.fulfilled'

    def handle(event)
      fulfillment = Spree::Fulfillment.find_by_prefix_id(event.payload['id'])
      integration = fulfillment && Spree::Integrations::Klaviyo.active_for(fulfillment.store)
      return unless integration

      SpreeKlaviyo::TrackEventJob.perform_later(
        integration, fulfillment, 'fulfilled_order',
        notify_customer: event.metadata.fetch('notify_customer', true) != false
      )
    end
  end
end
