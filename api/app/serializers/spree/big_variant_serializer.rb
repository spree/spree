module Spree
  class BigVariantSerializer < ActiveModel::Serializer
    root :variant

    # attributes *Spree::Api::ApiHelpers.variant_attributes
    attributes :id, :name, :is_master, :price, :in_stock, :sku, :display_price,
               :weight, :height, :width, :depth, :cost_price, :slug, :description,
               :options_text, :track_inventory, :product_id

    has_many :images, embed: :objects
    has_many :option_values, embed: :objects
    has_many :stock_items

    def cost_price
      if scope.current_api_user.has_spree_role? "admin"
        object.cost_price
      else
        false
      end
    end

    def in_stock
      object.in_stock?
    end
  end
end
