module Spree
  module Newsletter
    # Reconciles a Spree::NewsletterSubscriber with the customer who owns the email.
    # Backfills the user link and propagates verified opt-in onto the user record so
    # consent given before account creation isn't silently lost on registration.
    #
    # Best-effort: validation failures are logged but never re-raised. Callers are
    # already past the point where rolling back makes sense (the user record exists,
    # the subscription exists). This is reconciliation, not a precondition.
    class LinkUser
      def initialize(subscriber:, user:)
        @subscriber = subscriber
        @user = user
      end

      def call
        return if subscriber.blank? || user.blank?
        return if subscriber.user_id == user.id && !needs_marketing_propagation?

        link_subscriber_to_user
        propagate_marketing_consent if needs_marketing_propagation?

        subscriber
      end

      private

      attr_reader :subscriber, :user

      def link_subscriber_to_user
        return if subscriber.user_id == user.id

        return if subscriber.update(user: user)

        Rails.logger.warn(
          "NewsletterSubscriber #{subscriber.id} link to user #{user.id} failed: #{subscriber.errors.full_messages.to_sentence}"
        )
      end

      def needs_marketing_propagation?
        subscriber.verified? && !user.accepts_email_marketing?
      end

      def propagate_marketing_consent
        return if user.update(accepts_email_marketing: true)

        Rails.logger.warn(
          "User #{user.id} accepts_email_marketing update failed: #{user.errors.full_messages.to_sentence}"
        )
      end
    end
  end
end
