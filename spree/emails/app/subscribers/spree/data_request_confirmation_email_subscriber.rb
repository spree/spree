# frozen_string_literal: true

module Spree
  # Asks the person to confirm a request raised from their account, at the
  # address the request names, before Spree acts on it.
  class DataRequestConfirmationEmailSubscriber < Spree::Subscriber
    subscribes_to 'data_request.confirmation_requested'

    def handle(event)
      data_request = Spree::DataRequest.find_by_prefix_id(event.payload['id'])
      return unless data_request&.confirmable?
      return unless data_request.store.prefers_send_consumer_transactional_emails?

      CustomerMailer.data_request_confirmation_email(
        data_request,
        event.payload['confirmation_token'],
        redirect_url: event.payload['redirect_url']
      ).deliver_later
    end
  end
end
