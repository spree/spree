module Spree
  module Models
    module MailSettings

      # Override the Rails application mail settings based on preference.
      # This makes it possible to configure the mail settings
      # through an admin interface instead of requiring changes to the Rails envrionment file.
      def self.init
        ActionMailer::Base.default_url_options[:host] = Spree::Config[:site_url]
        return unless mail_method = Spree::MailMethod.current
        if mail_method.prefers_enable_mail_delivery?
          mail_server_settings = {
            :address => mail_method.preferred_mail_host,
            :domain => mail_method.preferred_mail_domain,
            :port => mail_method.preferred_mail_port,
            :authentication => mail_method.preferred_mail_auth_type
          }

          if mail_method.preferred_mail_auth_type != 'none'
            mail_server_settings[:user_name] = mail_method.preferred_smtp_username
            mail_server_settings[:password] = mail_method.preferred_smtp_password
          end

          tls = mail_method.preferred_secure_connection_type == 'TLS'
          mail_server_settings[:enable_starttls_auto] = tls

          ActionMailer::Base.smtp_settings = mail_server_settings
          ActionMailer::Base.perform_deliveries = true
        else
          #logger.warn "NOTICE: Mail not enabled"
          ActionMailer::Base.perform_deliveries = false
        end
      end

    end
  end
end
