# Default implementation of User.  This class is intended to be modified by extensions (ex. spree_auth_devise)
module Spree
  klass = SPREE_USER_CLASS == "Spree::User" ? ActiveRecord::Base : SPREE_USER_CLASS.constantize
  class User < klass
    if SPREE_USER_CLASS == "Spree::User"
      attr_accessible :email, :password, :password_confirmation 
      scope :registered
      attr_accessor :password
      attr_accessor :password_confirmation
    end

    belongs_to :ship_address, :class_name => 'Spree::Address'
    belongs_to :bill_address, :class_name => 'Spree::Address'


    def anonymous?
      false
    end

    # Creates an anonymous user
    def self.anonymous!
      create
    end

    def has_spree_role?(role)
      true
    end

  end
end
