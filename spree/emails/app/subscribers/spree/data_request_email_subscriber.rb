# frozen_string_literal: true

module Spree
  # Emails a finished subject access export to the person who asked for it.
  #
  # Erasure requests send nothing: the account's email address has just been
  # replaced with an undeliverable one, and writing to the old address would
  # re-record the very contact detail the request asked to remove.
  class DataRequestEmailSubscriber < Spree::Subscriber
    subscribes_to 'data_request.completed'

    def handle(event)
      data_request = Spree::DataRequest.find_by_prefix_id(event.payload['id'])
      return unless data_request&.access?
      return unless data_request.downloadable?
      return unless data_request.store.prefers_send_consumer_transactional_emails?

      CustomerMailer.data_export_email(data_request).deliver_later
    end
  end
end
