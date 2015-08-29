module Spree
  class ShippingMethodCategory < Spree::Base
    belongs_to :shipping_method
    belongs_to :shipping_category, inverse_of: :shipping_method_categories
  end
end
