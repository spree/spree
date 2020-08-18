module Spree
  module V2
    module Storefront
      class ProductSerializer < BaseSerializer
        set_type :product

        attributes :name, :description, :price, :currency, :display_price,
                   :compare_at_price, :display_compare_at_price, :available_on,
                   :slug, :meta_description, :meta_keywords, :updated_at

        attribute :purchasable,   &:purchasable?
        attribute :in_stock,      &:in_stock?
        attribute :backorderable, &:backorderable?
        attribute :available,     &:available?

        has_many :variants
        has_many :option_types
        has_many :product_properties
        has_many :taxons

        # all images from all variants
        has_many :images,
          object_method_name: :variant_images,
          id_method_name: :variant_image_ids,
          record_type: :image,
          serializer: :image

        has_one  :default_variant,
          object_method_name: :default_variant,
          id_method_name: :default_variant_id,
          record_type: :variant,
          serializer: :variant
      end
    end
  end
end
