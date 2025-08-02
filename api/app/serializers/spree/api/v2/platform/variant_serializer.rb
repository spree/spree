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

          belongs_to :product, serializer: Spree::Api::Dependencies.platform_product_serializer.constantize
          belongs_to :tax_category, serializer: Spree::Api::Dependencies.platform_tax_category_serializer.constantize
          has_many :digitals, serializer: Spree::Api::Dependencies.platform_digital_serializer.constantize
          has_many :images, serializer: Spree::Api::Dependencies.platform_image_serializer.constantize
          has_many :option_values, serializer: Spree::Api::Dependencies.platform_option_value_serializer.constantize
          has_many :stock_items, serializer: Spree::Api::Dependencies.platform_stock_item_serializer.constantize
          has_many :stock_locations, serializer: Spree::Api::Dependencies.platform_stock_location_serializer.constantize
        end
      end
    end
  end
end
