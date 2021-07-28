module Spree
  module Api
    module V2
      module Platform
        class VariantSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern
          include ::Spree::Api::V2::DisplayMoneyHelper

          set_type :variant

          attributes :name, :sku, :weight, :height, :width, :depth, :is_master,
                     :slug, :options_text, :description

          attribute :purchasable do |variant|
            variant.purchasable?
          end

          attribute :in_stock do |variant|
            variant.in_stock?
          end

          attribute :is_destroyed do |variant|
            variant.destroyed?
          end

          attribute :is_backorderable do |variant|
            variant.backorderable?
          end

          attribute :total_on_hand do |variant|
            variant.total_on_hand
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

          belongs_to :product
          has_many :images
          has_many :option_values
          has_many :stock_locations
          has_many :stock_items
        end
      end
    end
  end
end
