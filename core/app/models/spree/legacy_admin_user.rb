# Default implementation of AdminUser for testing purposes.
# This allows testing scenarios where user_class != admin_user_class
# Uses the same spree_users table as LegacyUser but as a separate class
module Spree
  class LegacyAdminUser < Spree.base_class
    include Spree::UserAddress
    include Spree::UserMethods

    self.table_name = 'spree_users'

    attr_accessor :password, :password_confirmation

    validates :email, presence: true, uniqueness: { case_sensitive: false }
  end
end
