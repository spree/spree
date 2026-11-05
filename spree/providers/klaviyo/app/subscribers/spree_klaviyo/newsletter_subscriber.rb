module SpreeKlaviyo
  # Hands every newsletter sign-up to Klaviyo, whose list decides whether to
  # send a confirmation, and revokes consent when a subscription is removed.
  class NewsletterSubscriber < Spree::Subscriber
    subscribes_to 'newsletter_subscriber.subscription_requested',
                  'newsletter_subscriber.verified',
                  'newsletter_subscriber.deleted'

    on 'newsletter_subscriber.subscription_requested', :subscribe
    on 'newsletter_subscriber.verified', :subscribe
    on 'newsletter_subscriber.deleted', :unsubscribe

    private

    def subscribe(event)
      subscriber = Spree::NewsletterSubscriber.find_by_prefix_id(event.payload['id'])
      return unless subscriber

      enqueue(subscriber.store, subscriber.email, subscribed: true)
    end

    # The row is gone, so the email comes from the event and the store is the
    # one the deletion ran in.
    def unsubscribe(event)
      enqueue(event.store, event.payload['email'], subscribed: false)
    end

    def enqueue(store, email, subscribed:)
      integration = Spree::Integrations::Klaviyo.active_for(store)
      return if integration.nil? || email.blank?

      SpreeKlaviyo::UpdateSubscriptionJob.perform_later(integration, email, subscribed: subscribed)
    end
  end
end
