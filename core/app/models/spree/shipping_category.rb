module Spree
  class ShippingCategory < Spree::Base
    validates :name, presence: true, uniqueness: { case_sensitive: false, allow_blank: true }

    with_options inverse_of: :shipping_category do
      has_many :products
      has_many :shipping_method_categories
    end
    has_many :shipping_methods, through: :shipping_method_categories
  end
end
