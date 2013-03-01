module Spree
  class MailMethod
    MAIL_AUTH = ['none', 'plain', 'login', 'cram_md5']
    SECURE_CONNECTION_TYPES = ['None','SSL','TLS']

    def self.current
      where(environment: Rails.env).first
    end
  end
end
