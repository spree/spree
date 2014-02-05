module Spree
  class ShippingCategory < ActiveRecord::Base
    validates :name, presence: true
    has_many :products, inverse_of: :shipping_category
    has_many :shipping_method_categories
    has_many :shipping_methods, through: :shipping_method_categories
  end
end