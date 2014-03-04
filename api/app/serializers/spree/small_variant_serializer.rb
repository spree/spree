module Spree
  class SmallVariantSerializer < ActiveModel::Serializer
    root :variant
    
    attributes :id, :name, :is_master, :price, :in_stock, :sku, :display_price,
               :weight, :height, :width, :depth, :cost_price, :slug, :description,
               :options_text, :track_inventory, :product_id

    has_many :images, embed: :objects
    has_many :option_values, embed: :objects

    def in_stock
      object.in_stock?
    end
  end
end
