module Spree
  class SmallVariantSerializer < ActiveModel::Serializer
    root :variant

    attributes :id, :name, :is_master, :price, :in_stock, :sku, :display_price,
               :weight, :height, :width, :depth, :cost_price, :slug, :description,
               :options_text, :track_inventory, :product_id, :total_on_hand, :is_destroyed,
              :is_backorderable

    has_many :images, embed: :objects
    has_many :option_values, embed: :objects

    def in_stock
      object.in_stock?
    end

    def is_backorderable
      object.is_backorderable?
    end

    def is_destroyed
      object.destroyed?
    end
  end
end
