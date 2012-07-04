# Default implementation of User.  This class is intended to be modified by extensions (ex. spree_auth)
module Spree
  class User < ActiveRecord::Base
    include Core::UserBanners
    attr_accessible :email, :password, :password_confirmation

    has_many :orders

    belongs_to :ship_address, :foreign_key => 'ship_address_id', :class_name => 'Spree::Address'
    belongs_to :bill_address, :foreign_key => 'bill_address_id', :class_name => 'Spree::Address'

    scope :registered

    def anonymous?
      false
    end

    # Creates an anonymous user
    def self.anonymous!
      create
    end

    attr_accessor :password
    attr_accessor :password_confirmation
  end
end
