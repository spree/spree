module Spree
  class TestMailer < BaseMailer
    def test_email(user)
      subject = "#{Spree::Config[:site_name]} #{Spree.t('test_mailer.test_email.subject')}"
      mail(to: user.email, from: from_address, subject: subject)
    end
  end
end
