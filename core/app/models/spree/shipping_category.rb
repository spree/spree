module Spree
  class ShippingCategory < ActiveRecord::Base
    validates :name, :presence => true
    has_many :products
    has_many :shipping_methods
  end
end
