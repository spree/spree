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

          if email_matches_current_user?(subscriber.email)
            # User's email is already verified by login — skip the double opt-in.
            Spree::Newsletter::Verify.new(subscriber: subscriber).call
          end
        end

        publish_subscription_requested unless subscriber.verified?
        subscriber
      end

      private

      attr_reader :email, :current_user, :current_store, :redirect_url

      def publish_subscription_requested
        event_name = 'newsletter_subscriber.subscription_requested'
        payload = subscriber.event_payload_for(
          event_name,
          include_verification_token: true, store: current_store, redirect_url: redirect_url.presence
        )
        subscriber.publish_event(event_name, payload)
      end

      def upsert_subscriber
        @upsert_subscriber ||= Spree::NewsletterSubscriber.find_or_create_by(email: email, store: current_store) do |new_record|
          new_record.customer = known_user
        end
      end
      alias_method :subscriber, :upsert_subscriber

      def existed_subscription
        @existed_subscription ||= Spree::NewsletterSubscriber.verified.find_by(email: email, store: current_store)
      end

      # The account the subscription belongs to: the signed-in customer only
      # when the address is theirs. Linking it to whoever is signed in would
      # hand them another person's subscription — and with it the right to
      # cancel it.
      def known_user
        @known_user ||= if email_matches_current_user?(email)
                          current_user
                        else
                          Spree.customer_class.find_by(email: email)
                        end
      end

      # Fold ASCII letters only; Unicode case folding can equate distinct mailboxes.
      def email_matches_current_user?(address)
        return false unless current_user

        current_user.email.to_s.downcase(:ascii) == address.to_s.downcase(:ascii)
      end
    end
  end
end
