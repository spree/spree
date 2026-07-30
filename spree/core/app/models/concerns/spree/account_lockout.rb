module Spree
  # Failed-login tracking and temporary account lockout, shared by the default
  # auth models (Customer, AdminUser). Thresholds are configuration-driven via
  # +Spree::Config[:max_failed_login_attempts]+ and +Spree::Config[:lockout_duration]+
  # (seconds). Enforcement lives in the authentication strategy — including this
  # concern opts a model in, but nothing locks until the login flow records attempts.
  module AccountLockout
    extend ActiveSupport::Concern

    included do
      attribute :failed_attempts, :integer, default: 0
    end

    # @return [Boolean] whether the account is currently within its lockout window
    def locked?
      locked_at.present? && locked_at > Spree::Config[:lockout_duration].seconds.ago
    end

    # Records a failed login attempt, locking the account once the configured
    # threshold is reached.
    # @return [void]
    def record_failed_attempt!
      increment!(:failed_attempts)
      update!(locked_at: Time.current) if failed_attempts >= Spree::Config[:max_failed_login_attempts]
    end

    # Clears the failed-attempt counter and any lockout. Call on successful login.
    # @return [void]
    def reset_failed_attempts!
      update!(failed_attempts: 0, locked_at: nil)
    end
  end
end
