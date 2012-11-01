module Spree
  class ProductOptionType < ActiveRecord::Base
    belongs_to :product
    belongs_to :option_type
    acts_as_list :scope => :product
  end
end
