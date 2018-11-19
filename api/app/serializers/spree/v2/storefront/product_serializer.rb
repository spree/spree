module Spree
  module V2
    module Storefront
      class ProductSerializer < BaseSerializer
        set_type :product

        attributes :name, :description, :price, :currency, :display_price,
                   :available_on, :slug, :meta_description, :meta_keywords,
                   :updated_at

        attribute :purchasable,   &:purchasable?
        attribute :in_stock,      &:in_stock?
        attribute :backorderable, &:backorderable?

        has_many :variants
        has_many :option_types
        has_many :product_properties

        has_one  :default_variant,
          object_method_name: :master,
          id_method_name: :master_id,
          record_type: :variant,
          serializer: :variant
      end
    end
  end
end
