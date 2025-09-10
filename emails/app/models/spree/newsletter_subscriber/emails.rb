module Spree
  class NewsletterSubscriber < Spree.base_class
    module Emails
      def deliver_newsletter_email_verification
        NewsletterMailer.email_confirmation(self).deliver_later
      end
    end
  end
end
