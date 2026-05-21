# frozen_string_literal: true

module Spree
  class NewsletterSubscriberEmailSubscriber < Spree::Subscriber
    # Listens to the `subscription_requested` event because that's where the
    # validated storefront `redirect_url` is carried. The mailer needs that URL
    # (or falls back to `store.storefront_url`) to build a verification link
    # that actually points to the storefront's confirmation page.
    subscribes_to 'newsletter_subscriber.subscription_requested'

    def handle(event)
      subscriber = find_subscriber(event)
      return unless subscriber
      return if subscriber.verified?

      store = subscriber.store || Spree::Current.store || Spree::Store.default
      return unless store.prefers_send_consumer_transactional_emails?

      NewsletterMailer.email_confirmation(subscriber, redirect_url: event.payload['redirect_url']).deliver_later
    end

    private

    def find_subscriber(event)
      subscriber_id = event.payload['id']
      Spree::NewsletterSubscriber.find_by_prefix_id(subscriber_id)
    end
  end
end
