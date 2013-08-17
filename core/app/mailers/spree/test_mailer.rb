module Spree
  class TestMailer < BaseMailer
    def test_email(mail_method, user)
      @mail_method = mail_method
      subject = "#{Spree::Config[:site_name]} #{t('test_mailer.test_email.subject')}"
      mail(:to => user.email, :from =>from_address, :subject => subject)
    end
  end
end
