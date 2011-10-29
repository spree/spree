# Default implementation of User.  This class is intended to be modified by extensions (ex. spree_auth)
class Spree::User < ActiveRecord::Base
  has_many :orders, :class_name => 'Spree::Order'

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
