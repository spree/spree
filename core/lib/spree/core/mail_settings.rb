module Spree
  module Core
    module MailSettings
      MAIL_AUTH = ['None', 'plain', 'login', 'cram_md5']
      SECURE_CONNECTION_TYPES = ['None','SSL','TLS']

      # Override the Rails application mail settings based on preference unless
      # a user_name was already set on the app smtp_settings
      # This makes it possible to configure the mail settings through an admin
      # interface instead of requiring changes to the Rails envrionment file.
      def self.init
        return if ActionMailer::Base.smtp_settings[:user_name]
        ActionMailer::Base.default_url_options[:host] ||= Spree::Config[:site_url]
        return if Spree::Config[:enable_mail_delivery].nil?

        if Spree::Config[:enable_mail_delivery]
          mail_server_settings = {
            :address => Spree::Config[:mail_host],
            :domain => Spree::Config[:mail_domain],
            :port => Spree::Config[:mail_port],
            :authentication => Spree::Config[:mail_auth_type]
          }

          if Spree::Config[:mail_auth_type] != 'None'
            mail_server_settings[:user_name] = Spree::Config[:smtp_username]
            mail_server_settings[:password] = Spree::Config[:smtp_password]
          end

          tls = Spree::Config[:secure_connection_type] == 'TLS'
          mail_server_settings[:enable_starttls_auto] = tls

          ActionMailer::Base.smtp_settings = mail_server_settings
          ActionMailer::Base.perform_deliveries = true
        else
          ActionMailer::Base.perform_deliveries = false
        end
      end
    end
  end
end
