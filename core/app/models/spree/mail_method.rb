module Spree
  class MailMethod < ActiveRecord::Base

    MAIL_AUTH = ['none', 'plain', 'login', 'cram_md5']
    SECURE_CONNECTION_TYPES = ['None','SSL','TLS']

    preference :enable_mail_delivery, :boolean, :default => false
    preference :mail_host, :string, :default => 'localhost'
    preference :mail_domain, :string, :default => 'localhost'
    preference :mail_port, :integer, :default => 25
    preference :mail_auth_type, :string, :default => MAIL_AUTH[0]
    preference :smtp_username, :string
    preference :smtp_password, :string
    preference :secure_connection_type, :string, :default => SECURE_CONNECTION_TYPES[0]
    preference :mails_from, :string, :default => 'no-reply@example.com'
    preference :mail_bcc, :string, :default => 'spree@example.com'
    preference :intercept_email, :string, :default => nil

    attr_accessible :environment, :preferred_enable_mail_delivery,
                    :preferred_mails_from, :preferred_mail_bcc,
                    :preferred_intercept_email, :preferred_mail_domain,
                    :preferred_mail_host, :preferred_mail_port,
                    :preferred_secure_connection_type, :preferred_mail_auth_type,
                    :preferred_smtp_username, :preferred_smtp_password

    validates :environment, :presence => true

    def self.current
      where(:environment => Rails.env).first
    end
  end
end
