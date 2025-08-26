module Spree
  module Newselleter
    class Subscribe
      helper Spree::AnalyticsHelper

      def initialize(email:, user: nil)
        @email = email
        @user = user
      end

      def call
        return if already_subscribed?
          
        if subscriber.new_record?
          subscriber.user = user_from_email
        else
          subscriber.regenerate_verification_token!
        end

        if email_already_verified_by_user?
          Spree::Newselleter::Verify.new(subscriber: subscriber).call
        else
          subscriber.save!
          ApplicationMailer.newsletter_subscription_confirmation(subscriber).deliver_later
        end

        track_event('subscribed_to_newsletter', { email: user.email, user: user })
        subscriber
      end

      private

      attr_reader :email, :user

      def subscriber
        @subscriber ||= Spree::NewsletterSubscriber.lock.find_or_initialize_by(email: email)
      end

      def email_already_verified_by_user?
        email == user&.email
      end

      def already_subscribed?
        Spree::NewsletterSubscriber.verified.exists?(email: email)
      end

      def user_from_email
        return @user_from_email if instance_variable_defined?(:@user_from_email)

        @user_from_email = Spree::User.find_by(email: email)
      end
    end
  end
end