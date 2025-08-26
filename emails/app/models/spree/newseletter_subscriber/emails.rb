module Spree
  class NewsletterSubscriber < ApplicationRecord
    module Emails
      def deliver_newsletter_subscription_confirmation
        NewsletterMailer.email_confirmation(self).deliver_later
      end
    end
  end
end
