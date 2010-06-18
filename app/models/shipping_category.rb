class ShippingCategory < ActiveRecord::Base
  has_many :shipping_rates

  validates :name, :presence => true
end
