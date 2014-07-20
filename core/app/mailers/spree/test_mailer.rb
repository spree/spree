module Spree
  class TestMailer < BaseMailer
    def test_email(email)
      mail(to: email, from: from_address, subject: 'Email test successfull.')
    end
  end
end
