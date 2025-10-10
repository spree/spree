module Spree
  module V2
    module Storefront
      class ProductSerializer < BaseSerializer
        include ::Spree::Api::V2::DisplayMoneyHelper
        include Spree::Api::V2::PublicMetafieldsConcern

        set_type :product

        attributes :name, :description, :available_on, :slug, :meta_description, :meta_keywords, :updated_at, :sku, :barcode, :public_metadata

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

        attribute :localized_slugs do |product, params|
          product.localized_slugs_for_store(params[:store])
        end

        attribute :tags, &:tag_list
        attribute :labels, &:label_list

        has_many :variants, serializer: Spree::Api::Dependencies.storefront_variant_serializer.constantize
        has_many :option_types, serializer: Spree::Api::Dependencies.storefront_option_type_serializer.constantize
        has_many :product_properties, serializer: Spree::Api::Dependencies.storefront_product_property_serializer.constantize

        has_many :taxons, serializer: Spree::Api::Dependencies.storefront_taxon_serializer.constantize, record_type: :taxon do |object, params|
          object.taxons_for_store(params[:store]).order(:id)
        end

        # all images from all variants
        has_many :images,
                 object_method_name: :variant_images,
                 id_method_name: :variant_image_ids,
                 record_type: :image,
                 serializer: Spree::Api::Dependencies.storefront_image_serializer.constantize

        has_one :default_variant,
                object_method_name: :default_variant,
                id_method_name: :default_variant_id,
                record_type: :variant,
                serializer: Spree::Api::Dependencies.storefront_variant_serializer.constantize

        has_one :primary_variant,
                object_method_name: :master,
                id_method_name: :master_id,
                record_type: :variant,
                serializer: Spree::Api::Dependencies.storefront_variant_serializer.constantize
      end
    end
  end
end
