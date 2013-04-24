module Spree
  class TestMailer < ActionMailer::Base
    def from_address
      Spree::Config[:mails_from]
    end

    def test_email(user)
      subject = "#{Spree::Config[:site_name]} #{t('test_mailer.test_email.subject')}"
      mail(:from => from_address, :to => user.email, :subject => subject)
    end
  end
end
