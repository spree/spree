module Spree
  class TestMailer < BaseMailer
    def test_email(user)
      recipient = user.respond_to?(:id) ? user : Spree.user_class.find(user)
      subject = "#{Spree::Config[:site_name]} #{Spree.t('test_mailer.test_email.subject')}"
      mail(to: recipient.email, from: from_address, subject: subject)
    end
  end
end
