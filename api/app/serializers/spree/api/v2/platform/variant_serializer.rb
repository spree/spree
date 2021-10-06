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

          belongs_to :product
          belongs_to :tax_category
          has_many :digitals
          has_many :images
          has_many :option_values
          has_many :stock_items
          has_many :stock_locations
        end
      end
    end
  end
end
