module Spree
  class ProductOptionType < Spree::Base
    belongs_to :product, inverse_of: :product_option_types
    belongs_to :option_type, inverse_of: :product_option_types
    acts_as_list scope: :product
  end
end
