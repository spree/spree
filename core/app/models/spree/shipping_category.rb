module Spree
  class ShippingCategory < Spree::Base
    validates :name, presence: true
    has_many :products, inverse_of: :shipping_category
    has_many :shipping_method_categories, inverse_of: :shipping_category
    has_many :shipping_methods, through: :shipping_method_categories
  end
end
