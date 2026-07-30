# Default staff/admin model.
# Ships in the gem with has_secure_password on the existing spree_admin_users table.
module Spree
  class AdminUser < Spree.base_class
    self.table_name = 'spree_admin_users'

    has_secure_password validations: false

    include Spree::AdminUserMethods
    include Spree::AccountLockout

    validates :email, presence: true, uniqueness: { case_sensitive: false }
    validates :password, confirmation: true, length: { maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED }, allow_blank: true

    # Back-compat with callers and auth strategies that check +valid_password?+.
    # Guards a blank digest (password-less accounts) so it returns false instead
    # of raising BCrypt::Errors::InvalidHash on older Rails/bcrypt versions.
    # @param password [String]
    # @return [Boolean]
    def valid_password?(password)
      return false if password_digest.blank?

      authenticate(password).present?
    end
  end
end
