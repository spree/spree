module Spree
  module V2
    module Storefront
      class VariantSerializer < BaseSerializer
        include ::Spree::Api::V2::DisplayMoneyHelper
        include Spree::Api::V2::PublicMetafieldsConcern

        set_type :variant

        attributes :sku, :barcode, :weight, :height, :width, :depth, :is_master, :options_text, :options, :public_metadata

        attribute :purchasable do |variant|
          variant.purchasable?
        end

        attribute :in_stock do |variant|
          variant.in_stock?
        end

        attribute :backorderable do |variant|
          variant.backorderable?
        end

        attribute :currency do |_product, params|
          params[:currency]
        end

        attribute :price do |product, params|
          price(product, params[:currency])
        end

        attribute :display_price do |product, params|
          display_price(product, params[:currency])
        end

        attribute :compare_at_price do |product, params|
          compare_at_price(product, params[:currency])
        end

        attribute :display_compare_at_price do |product, params|
          display_compare_at_price(product, params[:currency])
        end

        belongs_to :product, serializer: Spree.api.storefront_product_serializer
        has_many :images, serializer: Spree.api.storefront_image_serializer
        has_many :option_values, serializer: Spree.api.storefront_option_value_serializer
      end
    end
  end
end
