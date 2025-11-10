module Spree
  module Api
    module V2
      module Platform
        class ProductSerializer < BaseSerializer
          include ResourceSerializerConcern
          include DisplayMoneyHelper

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
            price(product, params[:currency], pricing_context_options(params))
          end

          attribute :display_price do |product, params|
            display_price(product, params[:currency], pricing_context_options(params))
          end

          attribute :compare_at_price do |product, params|
            compare_at_price(product, params[:currency], pricing_context_options(params))
          end

          attribute :display_compare_at_price do |product, params|
            display_compare_at_price(product, params[:currency], pricing_context_options(params))
          end

          def self.pricing_context_options(params)
            {
              store: params[:store],
              user: params[:user],
              tax_zone: params.dig(:price_options, :tax_zone)
            }
          end

          belongs_to :tax_category, serializer: Spree.api.platform_tax_category_serializer

          has_one :primary_variant,
                  object_method_name: :master,
                  id_method_name: :master_id,
                  record_type: :variant,
                  serializer: Spree.api.platform_variant_serializer

          has_one :default_variant,
                  object_method_name: :default_variant,
                  id_method_name: :default_variant_id,
                  record_type: :variant,
                  serializer: Spree.api.platform_variant_serializer

          has_many :variants, serializer: Spree.api.platform_variant_serializer
          has_many :option_types, serializer: Spree.api.platform_option_type_serializer
          has_many :product_properties, serializer: Spree.api.platform_product_property_serializer
          has_many :taxons, serializer: Spree.api.platform_taxon_serializer, record_type: :taxon do |object, params|
            if params[:store].present?
              object.taxons_for_store(params[:store])
            else
              object.taxons
            end
          end

          has_many :images,
                   object_method_name: :variant_images,
                   id_method_name: :variant_image_ids,
                   record_type: :image,
                   serializer: Spree.api.platform_image_serializer

          # TODO: add stock items
          # TODO: add prices
        end
      end
    end
  end
end
