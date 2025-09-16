module Spree
  module Newsletter
    class Subscribe
      def initialize(email:, current_user: nil)
        @email = email
        @current_user = current_user
      end

      def call
        return existed_subscription if existed_subscription.present?

        ActiveRecord::Base.transaction do
          upsert_subscriber
          return subscriber if subscriber.errors.any?

          if subscriber.email == current_user&.email || !Spree::NewsletterSubscriber.needs_verification?
            # no need to verified since user email is already verified
            Spree::Newsletter::Verify.new(subscriber: subscriber).call
          end
        end

        # deliver confirmation email after the transaction is completed
        subscriber.deliver_newsletter_email_verification unless subscriber.verified?
        subscriber
      end

      private

      attr_reader :email, :current_user

      def upsert_subscriber
        @upsert_subscriber ||= Spree::NewsletterSubscriber.find_or_create_by(email: email) do |new_record|
          new_record.user = Spree.user_class.find_by(email: new_record.email) || current_user
        end
      end
      alias_method :subscriber, :upsert_subscriber

      def existed_subscription
        @existed_subscription ||= Spree::NewsletterSubscriber.verified.find_by(email: email)
      end
    end
  end
end
