module Spree
  module Newsletter
    class Subscribe
      def initialize(email:, current_user: nil, current_store: nil, redirect_url: nil)
        @email = email
        @current_user = current_user
        @current_store = current_store || Spree::Store.current
        @redirect_url = redirect_url
      end

      def call
        return existed_subscription if existed_subscription.present?

        ActiveRecord::Base.transaction do
          upsert_subscriber
          return subscriber if subscriber.errors.any?

          if subscriber.email == current_user&.email
            # no need to verified since user email is already verified
            Spree::Newsletter::Verify.new(subscriber: subscriber).call
          end
        end

        publish_subscription_events unless subscriber.verified?
        subscriber
      end

      private

      attr_reader :email, :current_user, :current_store, :redirect_url

      def publish_subscription_events
        subscriber.publish_event(
          'newsletter_subscriber.subscription_requested',
          subscription_requested_payload
        )

        # Legacy lifecycle event — kept for the bundled Spree::NewsletterMailer
        # subscriber. Headless storefronts should listen to
        # `newsletter_subscriber.subscription_requested` instead since it carries
        # the verification_token and validated redirect_url.
        subscriber.publish_event('newsletter_subscriber.subscribed')
      end

      def subscription_requested_payload
        payload = {
          id: subscriber.prefixed_id,
          email: subscriber.email,
          verification_token: subscriber.verification_token,
          store_id: subscriber.store&.prefixed_id,
          customer_id: subscriber.user&.prefixed_id
        }
        payload[:redirect_url] = redirect_url if redirect_url.present?
        payload
      end

      def upsert_subscriber
        @upsert_subscriber ||= Spree::NewsletterSubscriber.find_or_create_by(email: email, store: current_store) do |new_record|
          new_record.user = Spree.user_class.find_by(email: new_record.email) || current_user
        end
      end
      alias_method :subscriber, :upsert_subscriber

      def existed_subscription
        @existed_subscription ||= Spree::NewsletterSubscriber.verified.find_by(email: email, store: current_store)
      end
    end
  end
end
