module Spree
  module V2
    module Storefront
      class VariantSerializer < BaseSerializer
        include ::Spree::Api::V2::DisplayMoneyHelper

        set_type :variant

        attributes :sku, :weight, :height, :width, :depth, :is_master, :options_text

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

        belongs_to :product
        has_many :images
        has_many :option_values
      end
    end
  end
end
