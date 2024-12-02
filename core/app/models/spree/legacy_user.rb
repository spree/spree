# Default implementation of User.  This class is intended to be modified by extensions (ex. spree_auth_devise)
module Spree
  class LegacyUser < Spree.base_class
    include Spree::UserAddress
    include Spree::UserPaymentSource
    include Spree::UserMethods
    include Spree::Metadata

    self.table_name = 'spree_users'

    attr_accessor :password, :password_confirmation, :first_name, :last_name
  end
end
