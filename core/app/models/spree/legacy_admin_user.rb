# Default implementation of AdminUser for staff/admin accounts.
# This class is separate from LegacyUser to support distinct customer vs staff models.
require 'bcrypt'

module Spree
  class LegacyAdminUser < Spree.base_class
    include Spree::AdminUserMethods

    self.table_name = 'spree_admin_users'

    attr_accessor :password, :password_confirmation

    validates :email, presence: true, uniqueness: { case_sensitive: false }

    before_save :encrypt_password, if: :password

    # Simple password validation for testing purposes
    # In production, Spree.admin_user_class should be overridden with a proper auth solution (e.g., Devise)
    def valid_password?(check_password)
      return false if encrypted_password.blank?

      BCrypt::Password.new(encrypted_password) == check_password
    end

    private

    def encrypt_password
      self.encrypted_password = BCrypt::Password.create(password)
    end
  end
end
