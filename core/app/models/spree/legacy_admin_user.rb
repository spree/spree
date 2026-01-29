# Default implementation of AdminUser for testing purposes.
# This allows testing scenarios where user_class != admin_user_class
module Spree
  class LegacyAdminUser < Spree.base_class
    include Spree::UserAddress
    include Spree::UserMethods

    self.table_name = 'spree_admin_users'

    attr_accessor :password, :password_confirmation

    validates :email, presence: true, uniqueness: { case_sensitive: false }
  end
end
