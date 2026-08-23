module Spree
  class OptionTypeProductType < Spree.base_class
    belongs_to :option_type, class_name: 'Spree::OptionType'
    belongs_to :product_type, class_name: 'Spree::ProductType'

    validates :product_type_id, uniqueness: { scope: :option_type_id }
  end
end
