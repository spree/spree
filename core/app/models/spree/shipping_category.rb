module Spree
  class ShippingCategory < Spree::Base
    validates :name, presence: true

    with_options inverse_of: :shipping_category do
      has_many :products
      has_many :shipping_method_categories
    end
    has_many :shipping_methods, through: :shipping_method_categories
    
    before_save :clear_cache

    def self.default
      Rails.cache.fetch("#{Rails.application.class.parent_name.underscore}_default_shipping_category") do
        first
      end
    end

    private
    def clear_cache
      Rails.cache.delete("#{Rails.application.class.parent_name.underscore}_default_shipping_category")
    end    
  end
end
