module Spree
  class ProductTypeCategory < Spree.base_class
    belongs_to :category, class_name: 'Spree::Category'
    belongs_to :product_type, class_name: 'Spree::ProductType'

    validates :product_type_id, uniqueness: { scope: :category_id }
  end
end
