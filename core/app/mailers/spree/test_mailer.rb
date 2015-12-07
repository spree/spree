module Spree
  class TestMailer < BaseMailer
    def test_email(email)
      @store = Spree::Store.current
      subject = "#{@store.name} #{Spree.t('test_mailer.test_email.subject')}"
      mail(to: email, from: from_address, subject: subject)
    end
  end
end
