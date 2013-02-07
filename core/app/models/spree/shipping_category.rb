module Spree
  class ShippingCategory < ActiveRecord::Base
    validates :name, presence: true
    has_many :products
    has_many :shipping_method_categories
    has_many :shipping_methods, through: :shipping_method_categories
  end
end
