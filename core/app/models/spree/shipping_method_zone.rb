module Spree
  class ShippingMethodZone < Spree::Base
    belongs_to :shipping_method
    belongs_to :zone
  end
end
