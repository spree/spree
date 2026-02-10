module Spree
  class TestMailer < BaseMailer
    def test_email(email)
      subject = "#{Spree::Store.default.name} #{Spree.t('test_mailer.test_email.subject')}"
      mail(to: email, from: from_address, reply_to: reply_to_address, subject: subject)
    end
  end
end
