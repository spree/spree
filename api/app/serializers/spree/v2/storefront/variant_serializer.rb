module Spree
  module V2
    module Storefront
      class VariantSerializer < BaseSerializer
        set_type :variant

        attributes :sku, :price, :currency, :display_price, :weight, :height,
                   :width, :depth, :is_master, :options_text

        attribute :purchasable,   &:purchasable?
        attribute :in_stock,      &:in_stock?
        attribute :backorderable, &:backorderable?

        belongs_to :product
        has_many :images
        has_many :option_values
      end
    end
  end
end
