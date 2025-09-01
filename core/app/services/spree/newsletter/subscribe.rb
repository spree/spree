module Spree
  module Newsletter
    class Subscribe
      def initialize(email:, user: nil)
        @email = email
        @user = user
      end

      def call
        return if already_subscribed?

        ActiveRecord::Base.transaction do
          upsert_subscriber
          
          if subscriber.email == user&.email
            # no need to verified since user email is already verified
            Spree::Newsletter::Verify.new(subscriber: subscriber).call
          elsif subscriber.previous_changes.blank?
            # non verified subscriber already existed
            subscriber.regenerate_verification_token
          end
        end

        # deliver confirmation email after the transaction is completed
        subscriber.deliver_newsletter_email_verification unless subscriber.verified?
      end

      private

      attr_reader :email, :user

      def upsert_subscriber
        @upsert_subscriber ||= Spree::NewsletterSubscriber.where(email: email).first_or_create do |new_record|
          new_record.user = Spree.user_class.find_by(email: new_record.email)
        end
      end
      alias_method :subscriber, :upsert_subscriber

      def already_subscribed?
        Spree::NewsletterSubscriber.verified.exists?(email: email)
      end
    end
  end
end
