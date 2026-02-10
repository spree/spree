module Spree
  class ShippingMethodCategory < Spree.base_class
    has_prefix_id :smcat

    belongs_to :shipping_method, class_name: 'Spree::ShippingMethod'
    belongs_to :shipping_category, class_name: 'Spree::ShippingCategory', inverse_of: :shipping_method_categories
  end
end
