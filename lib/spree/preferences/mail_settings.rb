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
            application_config = AppConfiguration.active.first
            logger.info "INFO: Loading mail preferences"

            if application_config.prefers_enable_mail_delivery?
              mail_server_settings = {
                :address => application_config.preferred_mail_host,
                :domain => application_config.preferred_mail_domain,
                :port => application_config.preferred_mail_port,
              }

              if application_config.preferred_mail_auth_type != 'none'
                mail_server_settings[:authentication] = application_config.preferred_mail_auth_type
                mail_server_settings[:user_name] = application_config.preferred_mail_username,
                mail_server_settings[:password] = application_config.preferred_mail_password
              end

              # Enable TLS
              if application_config.preferred_secure_connection_type == 'TLS'
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
