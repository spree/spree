module Spree
  class ProductOptionType < ActiveRecord::Base
    belongs_to :product, :class_name => Spree::Product
    belongs_to :option_type, :class_name => Spree::OptionType
    acts_as_list :scope => :product
  end
end
