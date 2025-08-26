module Spree
  class NewsletterMailer < BaseMailer
    def email_confirmation(subscriber)
      mail(to: @subscriber.email, from: from_address, subject: Spree.t('newsletter_mailer.email_confirmation.subject'))
    end
  end
end
