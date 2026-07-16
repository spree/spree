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
        if existed_subscription.present?
          Spree::Newsletter::LinkUser.new(subscriber: existed_subscription, user: known_user).call
          return existed_subscription
        end

        ActiveRecord::Base.transaction do
          upsert_subscriber
          return subscriber if subscriber.errors.any?

          Spree::Newsletter::LinkUser.new(subscriber: subscriber, user: known_user).call

          if subscriber.email == current_user&.email
            # User's email is already verified by login — skip the double opt-in.
            Spree::Newsletter::Verify.new(subscriber: subscriber).call
          end
        end

        subscriber.publish_event('newsletter_subscriber.subscription_requested', subscription_requested_payload) unless subscriber.verified?
        subscriber
      end

      private

      attr_reader :email, :current_user, :current_store, :redirect_url

      def subscription_requested_payload
        payload = {
          id: subscriber.prefixed_id,
          email: subscriber.email,
          verification_token: subscriber.verification_token,
          unsubscribe_token: subscriber.generate_token_for(:unsubscribe),
          store_id: current_store.prefixed_id,
          customer_id: subscriber.user&.prefixed_id
        }
        payload[:redirect_url] = redirect_url if redirect_url.present?
        payload
      end

      def upsert_subscriber
        @upsert_subscriber ||= Spree::NewsletterSubscriber.find_or_create_by(email: email, store: current_store) do |new_record|
          new_record.user = known_user
        end
      end
      alias_method :subscriber, :upsert_subscriber

      def existed_subscription
        @existed_subscription ||= Spree::NewsletterSubscriber.verified.find_by(email: email, store: current_store)
      end

      def known_user
        @known_user ||= current_user || Spree.user_class.find_by(email: email)
      end
    end
  end
end
