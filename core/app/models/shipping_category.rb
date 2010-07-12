class ShippingCategory < ActiveRecord::Base
  validates :name, :presence => true
end
