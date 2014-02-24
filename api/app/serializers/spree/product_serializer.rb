module Spree
  class ProductSerializer < ActiveModel::Serializer
    attributes :id, :name, :description, :price, :display_price,
               :available_on, :slug, :meta_description, :meta_keywords,
               :shipping_category_id, :taxon_ids, :has_variants

    has_many :variants, embed: :objects
    has_many :product_properties, embed: :objects, root: :properties
    has_many :option_types

    def has_variants
      object.has_variants?
    end
  end
end