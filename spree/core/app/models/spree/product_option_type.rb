module Spree
  class ProductOptionType < Spree.base_class
    with_options inverse_of: :product_option_types do
      belongs_to :product, class_name: 'Spree::Product'
      belongs_to :option_type, class_name: 'Spree::OptionType'
    end
    acts_as_list scope: :product

    validates :product_id, uniqueness: { scope: :option_type_id }, allow_nil: true
    validate :option_type_belongs_to_product_store

    private

    # Option types are store-owned, so a product may only use its own store's.
    def option_type_belongs_to_product_store
      return if product.nil? || option_type.nil?
      return if option_type.store_id == product.store_id

      errors.add(:option_type, :invalid)
    end
  end
end
