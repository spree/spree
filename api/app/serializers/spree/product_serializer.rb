module Spree
  class ProductSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.product_attributes
    attributes :id, :name, :description, :price, :display_price,
               :available_on, :slug, :meta_description, :meta_keywords,
               :shipping_category_id, :taxon_ids, :has_variants, :total_on_hand


    has_many :variants, embed: :objects, serializer: Spree::SmallVariantSerializer
    has_one :master, serializer: Spree::SmallVariantSerializer
    has_many :product_properties, embed: :objects
    has_many :option_types, serializer: Spree::SmallOptionTypeSerializer
    has_many :classifications, embed: :objects

    def has_variants
      object.has_variants?
    end

    def total_on_hand
      Spree::Config.track_inventory_levels ? object.total_on_hand : nil
    end
  end
end
