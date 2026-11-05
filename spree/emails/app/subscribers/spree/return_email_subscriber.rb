# frozen_string_literal: true

module Spree
  class ReturnEmailSubscriber < Spree::Subscriber
    subscribes_to 'return.refunded'

    def handle(event)
      return_record = find_return(event)
      return unless return_record

      return unless return_record.store.sends_customer_email?('spree/return_mailer/refunded_email')
      # A return owed nothing closes without a refund, so there is none to announce.
      return if return_record.refunded_total.zero?

      ReturnMailer.refunded_email(return_record.id).deliver_later
    end

    private

    def find_return(event)
      Spree::Return.find_by_prefix_id(event.payload['id'])
    end
  end
end
