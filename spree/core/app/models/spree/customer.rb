# Default storefront customer model.
#
# Ships in the gem with has_secure_password; apps needing extra columns add their
# own migrations against spree_customers or point Spree.customer_class at a custom
# model that includes Spree::CustomerMethods.
module Spree
  class Customer < Spree.base_class
    self.table_name = 'spree_customers'

    # `validations: false` — password presence is not enforced at the model level
    # (mirrors the previous LegacyUser default); storefront registration owns that
    # requirement, and admin-created customers claim their account via password reset.
    has_secure_password validations: false

    include Spree::CustomerMethods

    validates :email, presence: true, uniqueness: { case_sensitive: false }
    validates :password, confirmation: true, length: { maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED }, allow_blank: true

    attribute :failed_attempts, :integer, default: 0
    attribute :accepts_email_marketing, :boolean, default: false

    # Back-compat with callers and auth strategies that check +valid_password?+.
    # Guards a blank digest (password-less accounts) so it returns false instead
    # of raising BCrypt::Errors::InvalidHash on older Rails/bcrypt versions.
    # @param password [String]
    # @return [Boolean]
    def valid_password?(password)
      return false if password_digest.blank?

      authenticate(password).present?
    end

    # @return [Boolean] whether the account is currently locked out
    def locked?
      locked_at.present? && locked_at > 30.minutes.ago
    end

    def record_failed_attempt!
      increment!(:failed_attempts)
      update!(locked_at: Time.current) if failed_attempts >= 5
    end

    def reset_failed_attempts!
      update!(failed_attempts: 0, locked_at: nil)
    end
  end
end
