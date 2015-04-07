module Spree
  class ProductSerializer < ActiveModel::Serializer
    attributes :id, :name, :description, :price, :display_price,
               :available_on, :slug, :meta_description, :meta_keywords,
               :shipping_category_id, :taxon_ids, :has_variants

    has_many :variants, embed: :objects, serializer: Spree::SmallVariantSerializer
    has_one :master, serializer: Spree::SmallVariantSerializer
    has_many :product_properties, embed: :objects, root: :properties
    has_many :option_types, serializer: Spree::SmallOptionTypeSerializer

    def has_variants
      object.has_variants?
    end
  end
end