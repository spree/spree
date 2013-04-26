module Spree
  module Core
    class MailSettings
      MAIL_AUTH = ['None', 'plain', 'login', 'cram_md5']
      SECURE_CONNECTION_TYPES = ['None','SSL','TLS']

      # Override the Rails application mail settings based on preferences
      # This makes it possible to configure the mail settings through an admin
      # interface instead of requiring changes to the Rails envrionment file
      def self.init
        self.new.override! if override?
      end

      def self.override?
        Config.override_actionmailer_config
      end

      def override!
        if Config.enable_mail_delivery
          ActionMailer::Base.default_url_options[:host] ||= Config.site_url
          ActionMailer::Base.smtp_settings = mail_server_settings
          ActionMailer::Base.perform_deliveries = true
        else
          ActionMailer::Base.perform_deliveries = false
        end
      end

      private
        def mail_server_settings
          settings = if need_authentication?
            basic_settings.merge(user_credentials)
          else
            basic_settings
          end

          settings.merge :enable_starttls_auto => secure_connection?
        end

        def user_credentials
          { :user_name => Config.smtp_username,
            :password => Config.smtp_password }
        end

        def basic_settings
          { :address => Config.mail_host,
            :domain => Config.mail_domain,
            :port => Config.mail_port,
            :authentication => Config.mail_auth_type }
        end

        def need_authentication?
          Config.mail_auth_type != 'None'
        end

        def secure_connection?
          Config.secure_connection_type == 'TLS'
        end
    end
  end
end
