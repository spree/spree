module Spree
  module Emails
    # Finds the return or exchange an event names and delivers the email the
    # block builds, unless the store sends its own customer emails.
    module PostSaleDelivery
      private

      def deliver(model_class, event)
        record = model_class.find_by_prefix_id(event.payload['id'])
        return unless record
        return unless record.store.prefers_send_consumer_transactional_emails?
        # Withdrawn before the email went out: nothing to acknowledge, and the
        # memo may by now hold the staff cancellation note.
        return if record.canceled?

        yield(record)&.deliver_later
      end
    end
  end
end
