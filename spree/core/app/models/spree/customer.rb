# Default storefront customer model.
#
# Ships in the gem with has_secure_password; apps needing extra columns add their
# own migrations against spree_customers or point Spree.customer_class at a custom
# model that includes Spree::CustomerMethods.
module Spree
  class Customer < Spree.base_class
    self.table_name = 'spree_customers'

    # `validations: false` — password presence is not enforced at the model level;
    # storefront registration owns that requirement, and admin-created customers
    # claim their account via password reset.
    has_secure_password validations: false

    include Spree::CustomerMethods
    include Spree::AccountLockout
    include Spree::PasswordPolicy

    validates :email, presence: true, uniqueness: { case_sensitive: false }

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
  end
end
