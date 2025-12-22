module Spree
  module Api
    module V2
      module Platform
        class VariantSerializer < BaseSerializer
          include ResourceSerializerConcern
          include DisplayMoneyHelper

          attributes :name, :options_text, :total_on_hand

          attribute :purchasable do |product|
            product.purchasable?
          end

          attribute :in_stock do |product|
            product.in_stock?
          end

          attribute :backorderable do |product|
            product.backorderable?
          end

          attribute :available do |product|
            product.available?
          end

          attribute :currency do |_product, params|
            params[:currency]
          end

          attribute :price do |object, params|
            price(object, params[:currency])
          end

          attribute :display_price do |object, params|
            display_price(object, params[:currency])
          end

          attribute :compare_at_price do |object, params|
            compare_at_price(object, params[:currency])
          end

          attribute :display_compare_at_price do |object, params|
            display_compare_at_price(object, params[:currency])
          end

          belongs_to :product, serializer: Spree.api.platform_product_serializer
          belongs_to :tax_category, serializer: Spree.api.platform_tax_category_serializer
          has_many :digitals, serializer: Spree.api.platform_digital_serializer
          has_many :images, serializer: Spree.api.platform_image_serializer
          has_many :option_values, serializer: Spree.api.platform_option_value_serializer
          has_many :stock_items, serializer: Spree.api.platform_stock_item_serializer
          has_many :stock_locations, serializer: Spree.api.platform_stock_location_serializer
        end
      end
    end
  end
end
