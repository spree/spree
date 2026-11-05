module SpreeKlaviyo
  # Sends Return Refunded for each refund of a return, as Spree's refund email
  # is sent: skipped when nothing was refunded.
  class ReturnSubscriber < Spree::Subscriber
    subscribes_to 'return.refunded'

    def handle(event)
      return_record = Spree::Return.find_by_prefix_id(event.payload['id'])
      integration = return_record && Spree::Integrations::Klaviyo.active_for(return_record.store)
      return if integration.nil? || return_record.refunded_total.zero?

      SpreeKlaviyo::TrackEventJob.perform_later(
        integration, return_record, 'return_refunded',
        event_id: event.id, published_at: event.created_at
      )
    end
  end
end
