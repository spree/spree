# Allows us to intercept any outbound mail message and make last minute changes
# (such as specifying a "from" address or sending to a test email account)
#
# See http://railscasts.com/episodes/206-action-mailer-in-rails-3 for more details.
module Spree
  module Core
    class MailInterceptor
      def self.delivering_email(message)
        return if Spree::Config[:enable_mail_delivery].nil?
        message.from ||= Spree::Config[:mails_from]

        if Spree::Config[:intercept_email].present?
          message.subject = "#{message.to} #{message.subject}"
          message.to = Spree::Config[:intercept_email]
        end

        if Spree::Config[:mail_bcc].present?
          message.bcc ||= Spree::Config[:mail_bcc]
        end
      end
    end
  end
end
