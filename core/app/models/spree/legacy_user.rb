# Default implementation of User.  This class is intended to be modified by extensions (ex. spree_auth_devise)
require 'bcrypt'

module Spree
  class LegacyUser < Spree.base_class
    include Spree::UserAddress
    include Spree::UserPaymentSource
    include Spree::UserMethods

    self.table_name = 'spree_users'

    attr_accessor :password, :password_confirmation

    validates :email, presence: true, uniqueness: { case_sensitive: false }

    before_save :encrypt_password, if: :password

    # Simple password validation for testing purposes
    # In production, Spree.user_class should be overridden with a proper auth solution (e.g., Devise)
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
