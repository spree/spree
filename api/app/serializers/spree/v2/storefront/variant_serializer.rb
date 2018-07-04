module Spree
  module V2
    module Storefront
      class VariantSerializer < BaseSerializer
        set_type :variant

        attributes :name, :sku, :price, :currency, :display_price, :weight, :height,
                   :width, :depth, :is_master, :options_text, :slug, :description,
                   :track_inventory

        attribute :purchasable do |variant|
          variant.purchasable?
        end

        attribute :in_stock do |variant|
          variant.in_stock?
        end

        attribute :backorderable do |variant|
          variant.backorderable?
        end

        has_many :images
      end
    end
  end
end
