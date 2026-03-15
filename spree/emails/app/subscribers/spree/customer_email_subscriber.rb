# frozen_string_literal: true

module Spree
  class CustomerEmailSubscriber < Spree::Subscriber
    subscribes_to 'customer.password_reset_requested'

    def handle(event)
      email = event.payload['email']
      return if email.blank?

      user = Spree.user_class.find_by(email: email)
      return unless user

      store = find_store(event)
      return unless store
      return unless store.prefers_send_consumer_transactional_emails?

      reset_token = event.payload['reset_token']
      redirect_url = event.payload['redirect_url']

      CustomerMailer.password_reset_email(
        user.id,
        store.id,
        reset_token,
        redirect_url
      ).deliver_later
    end

    private

    def find_store(event)
      store_id = event.store_id
      return Spree::Store.find(store_id) if store_id.present?

      Spree::Current.store || Spree::Store.default
    end
  end
end
