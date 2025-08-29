module Spree
  class NewsletterSubscriber < Spree.base_class
    module Emails
      extend ActiveSupport::Concern

      def deliver_newsletter_subscription_confirmation
        # you can overwrite this method in your application / extension to send out the confirmation email
        # or use `spree_emails` gem
      end
    end
  end
end
