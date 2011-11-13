module Spree
  class ShippingCategory < ActiveRecord::Base
    validates :name, :presence => true
  end
end
