module Spree
  class ProductOptionType < Spree::Base
    belongs_to :product, class_name: 'Spree::Product', inverse_of: :product_option_types
    belongs_to :option_type, class_name: 'Spree::OptionType', inverse_of: :product_option_types
    acts_as_list scope: :product
  end
end
