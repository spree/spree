# frozen_string_literal: true

module Spree
  class CustomerEmailSubscriber < Spree::Subscriber
    subscribes_to 'customer.password_reset_requested'

    def handle(event)
      user = Spree.user_class.find_by(email: event.payload['email'])
      return unless user

      store = find_store(event)
      return unless store.prefers_send_consumer_transactional_emails?

      CustomerMailer.password_reset_email(
        user,
        event.payload['reset_token'],
        store,
        redirect_url: event.payload['redirect_url']
      ).deliver_later
    end

    private

    def find_store(event)
      Spree::Store.find_by_prefix_id(event.payload['store_id']) ||
        Spree::Current.store ||
        Spree::Store.default
    end
  end
end
