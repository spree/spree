module Spree
  module Admin
    module AuthRateLimiting
      extend ActiveSupport::Concern

      class_methods do
        # @param limit_preference [Symbol] e.g. :rate_limit_login / :rate_limit_password_reset
        # @param redirect_to [Proc] evaluated in controller context to the path to bounce
        #   back to when rate limited, e.g. `-> { new_session_path(resource_name) }`.
        # @return [void]
        def auth_rate_limit(limit_preference, redirect_to:)
          limit  = Spree::Admin::RuntimeConfig[limit_preference] || 5
          window = (Spree::Admin::RuntimeConfig[:rate_limit_window] || 60).seconds
          prefix = limit_preference.to_s # unique namespace per controller/action

          # By IP — always present; backstops blank-email floods.
          rate_limit(
            to: limit,
            within: window,
            by: -> { "#{prefix}-ip:#{request.remote_ip}" },
            with: -> { admin_auth_rate_limit_response(redirect_to) },
            store: Rails.cache,
            only: :create
          )

          # By submitted email (case-insensitive). Falls back to per-IP bucketing when
          # the email is blank, so blank submissions don't all share one global bucket.
          rate_limit(
            to: limit,
            within: window,
            by: lambda {
              email = admin_auth_rate_limit_email
              email.present? ? "#{prefix}-email:#{email}" : "#{prefix}-email-ip:#{request.remote_ip}"
            },
            with: -> { admin_auth_rate_limit_response(redirect_to) },
            store: Rails.cache,
            only: :create
          )
        end
      end

      private

      # Email is read via Devise's `resource_params` so it works regardless of the
      # configured admin user class / resource param key.
      def admin_auth_rate_limit_email
        resource_params[:email].to_s.strip.downcase.presence
      rescue StandardError
        nil
      end

      def admin_auth_rate_limit_response(redirect_path)
        flash[:alert] = I18n.t('devise.failure.too_many_attempts')
        redirect_to instance_exec(&redirect_path)
      end
    end
  end
end
