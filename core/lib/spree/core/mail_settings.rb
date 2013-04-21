module Spree
  module Core
    class MailSettings
      # Override the Rails application mail settings based on preferences
      # This makes it possible to configure the mail settings through an admin
      # interface instead of requiring changes to the Rails envrionment file
      def self.init
        instance = new
        instance.override! if instance.override?
      end

      def override!
        if mail_method.prefers_enable_mail_delivery?
          ActionMailer::Base.default_url_options[:host] ||= Spree::Config[:site_url]
          ActionMailer::Base.smtp_settings = mail_server_settings
          ActionMailer::Base.perform_deliveries = true
        else
          ActionMailer::Base.perform_deliveries = false
        end
      end

      def override?
        override_actionmailer_config? && mail_method
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
          { :user_name => mail_method.preferred_smtp_username,
            :password => mail_method.preferred_smtp_password }
        end

        def basic_settings
          { :address => mail_method.preferred_mail_host,
            :domain => mail_method.preferred_mail_domain,
            :port => mail_method.preferred_mail_port,
            :authentication => mail_method.preferred_mail_auth_type }
        end

        def need_authentication?
          mail_method.preferred_mail_auth_type != 'none'
        end

        def secure_connection?
          mail_method.preferred_secure_connection_type == 'TLS'
        end

        def mail_method
          Spree::MailMethod.current
        end

        def override_actionmailer_config?
          Spree::Config.override_actionmailer_config
        end
    end
  end
end
