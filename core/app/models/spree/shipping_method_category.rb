module Spree
  class ShippingMethodCategory < ActiveRecord::Base
    belongs_to :shipping_method, class_name: 'Spree::ShippingMethod'
    belongs_to :shipping_category, class_name: 'Spree::ShippingCategory'
  end
end
