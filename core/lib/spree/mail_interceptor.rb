# Allows us to intercept any outbound mail message and make last minute changes (such as specifying a "from" address or
# sending to a test email account.)
#
# See http://railscasts.com/episodes/206-action-mailer-in-rails-3 for more details.
module Spree
  class MailInterceptor

    def self.delivering_email(message)
      return unless mail_method = MailMethod.current
      message.from ||= mail_method.preferred_mails_from

      if mail_method.preferred_intercept_email.present?
        message.subject = "[#{message.to}] #{message.subject}"
        message.to = mail_method.preferred_intercept_email
      end

      if mail_method.preferred_mail_bcc.present?
        message.bcc = mail_method.preferred_mail_bcc
      end
    end

  end
end