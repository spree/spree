module Spree
  module Newselleter
    class Verify
      def initialize(subscriber:)
        @subscriber = subscriber
      end

      def call
        verify_subscriber
        set_user_email_marketing_to_true

        subscriber
      end

      private

      attr_reader :subscriber

      def verify_subscriber
        subscriber.update!(verified_at: Time.current)
      end

      def set_user_email_marketing_to_true
        return if subscriber.user.blank?

        subscriber.user.update!(email_marketing: true)
      end
    end
  end
end