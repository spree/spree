module Spree
  class Contact < MailForm::Base
    attribute :name, validate: true
    attribute :email, validate: /\A([\w.%+\-]+)@([\w\-]+\.)+(\w{2,})\z/i
    attribute :message, validate: true
    attribute :customer_support_email, validate: :customer_support_email_bug?

    def headers
      {
        subject: 'Contact Us',
        to: customer_support_email.to_s,
        from: %("#{name}" <#{email}>)
      }
    end

    def customer_support_email_bug?
      errors.add(:customer_support_email, 'is not there') if customer_support_email.nil? || customer_support_email.empty?
    end

    def [](key)
      send(key)
    end
  end
end
