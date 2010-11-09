# Default implementation of User.  This class is intended to be modified by extensions (ex. spree_auth)
class User < ActiveRecord::Base

  has_many :orders
  belongs_to :ship_address, :foreign_key => "ship_address_id", :class_name => "Address"
  belongs_to :bill_address, :foreign_key => "bill_address_id", :class_name => "Address"

  def anonymous?
    false
  end

  # Creates an anonymous user
  def self.anonymous!
    User.create
  end

end
