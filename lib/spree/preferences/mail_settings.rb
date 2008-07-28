module Spree
  module Preferences
    # This class handle mail settings using preferences feature available in spree core.
    class MailSettings

      class << self

        # When loading from config/initializers/spree.rb the logger
        # variable is not available yet, so defining it here.
        def logger
          RAILS_DEFAULT_LOGGER
        end

        def init
          # Set mail server settings from preferences
          begin
            logger.info "INFO: Loading mail preferences"

            if Spree::Config.instance.prefers_enable_mail_delivery?
              mail_server_settings = {
                :address => Spree::Config[:mail_host],
                :domain => Spree::Config[:mail_domain],
                :port => Spree::Config[:mail_port],
              }

              if Spree::Config[:mail_auth_type] != 'none'
                mail_server_settings[:authentication] = Spree::Config[:mail_auth_type]
                mail_server_settings[:user_name] = Spree::Config[:smtp_username]
                mail_server_settings[:password] = Spree::Config[:smtp_password]
              end

              # Enable TLS
              if Spree::Config[:secure_connection_type] == 'TLS'
                Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
              end

              logger.info "INFO: Setting mails settings to #{mail_server_settings.inspect}"
              ActionMailer::Base.smtp_settings = mail_server_settings
              logger.info "INFO: Enabling mail delivery"
              ActionMailer::Base.perform_deliveries = true
              return true
            else
              logger.warn "NOTICE: Mail not enabled"
              ActionMailer::Base.perform_deliveries = false
              return false
            end
          rescue
            logger.error "========================================================================="
            logger.error "ERROR: Something went wrong while loading mail preferences"
            logger.error "       Verify you created a default configuration in admin/configurations"
            logger.error "========================================================================="
          end
        end 
      end
    end
  end
end
