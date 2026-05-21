module Spree
  module Newsletter
    class Subscribe
      def initialize(email:, current_user: nil, current_store: nil)
        @email = email
        @current_user = current_user
        @current_store = current_store || Spree::Store.current
      end

      def call
        if existed_subscription.present?
          associate_subscriber_to_known_user!(existed_subscription)
          return existed_subscription
        end

        ActiveRecord::Base.transaction do
          upsert_subscriber
          return subscriber if subscriber.errors.any?
          associate_subscriber_to_known_user!(subscriber)

          if subscriber.email == current_user&.email
            # no need to verified since user email is already verified
            Spree::Newsletter::Verify.new(subscriber: subscriber).call
          end
        end

        # publish event to trigger email delivery via subscriber
        subscriber.publish_event('newsletter_subscriber.subscribed') unless subscriber.verified?
        subscriber
      end

      private

      attr_reader :email, :current_user, :current_store

      def upsert_subscriber
        @upsert_subscriber ||= Spree::NewsletterSubscriber.find_or_create_by(email: email, store: current_store) do |new_record|
          new_record.user = Spree.user_class.find_by(email: new_record.email) || current_user
        end
      end
      alias_method :subscriber, :upsert_subscriber

      def existed_subscription
        @existed_subscription ||= Spree::NewsletterSubscriber.verified.find_by(email: email, store: current_store)
      end

      def associate_subscriber_to_known_user!(subscriber_record)
        known_user = current_user || Spree.user_class.find_by(email: subscriber_record.email)
        return if known_user.blank?

        subscriber_record.update!(user: known_user) if subscriber_record.user != known_user
        return unless subscriber_record.verified? && !known_user.accepts_email_marketing?

        known_user.update!(accepts_email_marketing: true)
      end
    end
  end
end
