# frozen_string_literal: true

module Spree
  class NewsletterSubscriberEmailSubscriber < Spree::Subscriber
    subscribes_to 'newsletter_subscriber.subscribed'

    def handle(event)
      subscriber = find_subscriber(event)
      return unless subscriber
      return if subscriber.verified?

      store = Spree::Current.store || Spree::Store.default
      return unless store.prefers_send_consumer_transactional_emails?

      NewsletterMailer.email_confirmation(subscriber).deliver_later
    end

    private

    def find_subscriber(event)
      subscriber_id = event.payload['id']
      Spree::NewsletterSubscriber.find_by_prefix_id(subscriber_id)
    end
  end
end
