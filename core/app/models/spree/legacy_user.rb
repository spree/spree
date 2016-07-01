# Default implementation of User.  This class is intended to be modified by extensions (ex. spree_auth_devise)
module Spree
  class LegacyUser < Spree::Base
    include UserAddress
    include UserPaymentSource
    include UserMethods

    self.table_name = 'spree_users'

    attr_accessor :password
    attr_accessor :password_confirmation
  end
end
