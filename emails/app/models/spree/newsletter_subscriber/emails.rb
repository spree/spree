module Spree
  class NewsletterSubscriber < Spree.base_class
    module Emails
      def store
        @store ||= Spree::Store.current || Spree::Store.default
      end

      def deliver_newsletter_email_verification
        NewsletterMailer.email_confirmation(self).deliver_later if store.prefers_send_consumer_transactional_emails?
      end
    end
  end
end
