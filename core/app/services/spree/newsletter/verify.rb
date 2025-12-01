module Spree
  module Newsletter
    class Verify
      def initialize(subscriber:)
        @subscriber = subscriber
      end

      def call
        verify_subscriber
        set_user_email_marketing_to_true
        publish_event

        subscriber
      end

      private

      attr_reader :subscriber

      def verify_subscriber
        subscriber.update!(verified_at: Time.current, verification_token: nil)
      end

      def set_user_email_marketing_to_true
        return if subscriber.user.blank?

        subscriber.user.update!(accepts_email_marketing: true)
      end

      def publish_event
        subscriber.publish_event('newsletter_subscriber.verify')
      end
    end
  end
end
