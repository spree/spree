module Spree
  module V2
    module Storefront
      class ProductSerializer < BaseSerializer
        include ::Spree::Api::V2::DisplayMoneyHelper

        set_type :product

        attributes :name, :description, :available_on, :slug, :meta_description, :meta_keywords, :updated_at

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

        has_many :variants
        has_many :option_types
        has_many :product_properties
        has_many :taxons

        # all images from all variants
        has_many :images,
          object_method_name: :variant_images,
          id_method_name: :variant_image_ids,
          record_type: :image,
          serializer: :image

        has_one  :default_variant,
          object_method_name: :default_variant,
          id_method_name: :default_variant_id,
          record_type: :variant,
          serializer: :variant
      end
    end
  end
end
