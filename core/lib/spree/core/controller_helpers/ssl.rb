module Spree
  module Core
    module ControllerHelpers
      module SSL
        extend ActiveSupport::Concern

        included do
          before_filter :force_non_ssl_redirect, :if => Proc.new { Spree::Config[:redirect_https_to_http] }
          class_attribute :ssl_allowed_actions

          def self.ssl_allowed(*actions)
            self.ssl_allowed_actions ||= []
            self.ssl_allowed_actions.concat actions
          end

          def self.ssl_required(*actions)
            ssl_allowed *actions
            if ssl_supported?
              if actions.empty? or Rails.application.config.force_ssl
                force_ssl
              else
                force_ssl :only => actions
              end
            end
          end

          def self.ssl_supported?
            return Spree::Config[:allow_ssl_in_production] if Rails.env.production?
            return Spree::Config[:allow_ssl_in_staging] if Rails.env.staging?
            return Spree::Config[:allow_ssl_in_development_and_test] if (Rails.env.development? or Rails.env.test?)
          end

          private
            def ssl_allowed?
              (!ssl_allowed_actions.nil? && (ssl_allowed_actions.empty? || ssl_allowed_actions.include?(action_name.to_sym)))
            end

            # Redirect the existing request to use the HTTP protocol.
            #
            # ==== Parameters
            # * <tt>host</tt> - Redirect to a different host name
            def force_non_ssl_redirect(host = nil)
              if request.ssl? && !ssl_allowed?
                redirect_options = {
                  :protocol => 'http://',
                  :host     => host || request.host,
                  :path     => request.fullpath,
                }
                flash.keep if respond_to?(:flash)
                insecure_url = ActionDispatch::Http::URL.url_for(redirect_options)
                redirect_to insecure_url, :status => :moved_permanently
              end
            end
        end
      end
    end
  end
end
