class ShippingCategory < ActiveRecord::Base
  has_many :shipping_rates

  validates_presence_of :name
end
