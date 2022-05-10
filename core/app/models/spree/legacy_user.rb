# Default implementation of User.  This class is intended to be modified by extensions (ex. spree_auth_devise)
module Spree
  class LegacyUser < Spree::Base
    include UserAddress
    include UserPaymentSource
    include UserMethods
    include Spree::Metadata

    self.table_name = 'spree_users'

    attr_accessor :password, :password_confirmation
  end
end
