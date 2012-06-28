# Default implementation of User.  This class is intended to be modified by extensions (ex. spree_auth_devise)
module Spree
  if Spree.user_class 
    class User < Spree.user_class
    end
  else
    class User < ActiveRecord::Base
      attr_accessible :email, :password, :password_confirmation
      scope :registered

      def anonymous?
        false
      end

      attr_accessor :password
      attr_accessor :password_confirmation
    end
  end

  class User

    belongs_to :ship_address, :class_name => 'Spree::Address'
    belongs_to :bill_address, :class_name => 'Spree::Address'

    # Creates an anonymous user
    def self.anonymous!
      create
    end

    def has_spree_role?(role)
      true
    end

  end
end
