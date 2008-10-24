class ShippingCategory < ActiveRecord::Base
  has_many :shipping_methods
  validates_presence_of :name
end
