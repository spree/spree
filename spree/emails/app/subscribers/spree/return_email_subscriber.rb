# frozen_string_literal: true

module Spree
  class ReturnEmailSubscriber < Spree::Subscriber
    subscribes_to 'return.refunded'

    def handle(event)
      return_record = find_return(event)
      return unless return_record

      store = return_record.store
      return unless store.prefers_send_consumer_transactional_emails?

      ReturnMailer.refunded_email(return_record.id).deliver_later
    end

    private

    def find_return(event)
      Spree::Return.find_by_prefix_id(event.payload['id'])
    end
  end
end
