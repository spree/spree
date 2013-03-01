module Spree
  class ShippingMethodCategory < ActiveRecord::Base
    belongs_to :shipping_method
    belongs_to :shipping_category
  end
end
