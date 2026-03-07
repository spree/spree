module Spree
  module Api
    module V3
      module Admin
        # Admin API Product Serializer
        # Full product data including admin-only fields
        # Extends the store serializer with additional attributes
        class ProductSerializer < V3::ProductSerializer

          # Additional type hints for admin-only computed attributes
          # Override price/original_price to reference AdminPrice instead of StorePrice
          typelize status: :string, make_active_at: [:string, nullable: true], discontinue_on: [:string, nullable: true],
                   cost_price: [:string, nullable: true], cost_currency: [:string, nullable: true],
                   deleted_at: [:string, nullable: true],
                   meta_title: [:string, nullable: true], promotionable: :boolean,
                   shipping_category_id: [:string, nullable: true], tax_category_id: [:string, nullable: true],
                   price: 'AdminPrice', original_price: ['AdminPrice', nullable: true]

          # Admin-only attributes
          attributes :status, :make_active_at, :discontinue_on, :meta_title, :promotionable,
                     deleted_at: :iso8601

          attribute :shipping_category_id do |product|
            product.shipping_category&.prefixed_id
          end

          attribute :tax_category_id do |product|
            product.tax_category&.prefixed_id
          end

          attribute :cost_price do |product|
            product.master&.cost_price
          end

          attribute :cost_currency do |product|
            product.master&.cost_currency
          end

          # Override price/original_price to use admin price serializer
          attribute :price do |product|
            price = price_for(product.default_variant)
            Spree.api.admin_price_serializer.new(price, params: params).to_h if price.present?
          end

          attribute :original_price do |product|
            variant = product.default_variant
            calculated = price_for(variant)
            base = price_in(variant)

            if calculated.present? && base.present? && calculated.id != base.id
              Spree.api.admin_price_serializer.new(base, params: params).to_h
            end
          end

          # Override all nested associations to use admin serializers
          many :variant_images,
               key: :images,
               resource: Spree.api.admin_image_serializer,
               if: proc { expand?('images') }

          many :variants,
               resource: Spree.api.admin_variant_serializer,
               if: proc { expand?('variants') }

          one :default_variant,
              resource: Spree.api.admin_variant_serializer,
              if: proc { expand?('default_variant') }

          one :master,
              key: :master_variant,
              resource: Spree.api.admin_variant_serializer,
              if: proc { expand?('master_variant') }

          many :option_types,
               resource: Spree.api.admin_option_type_serializer,
               if: proc { expand?('option_types') }

          many :taxons,
               proc { |taxons, params|
                 taxons.select { |t| t.taxonomy.store_id == params[:store].id }
               },
               resource: Spree.api.admin_taxon_serializer,
               if: proc { expand?('taxons') }

          many :metafields,
               resource: Spree.api.admin_metafield_serializer,
               if: proc { expand?('metafields') }

          one :shipping_category,
              resource: Spree.api.admin_shipping_category_serializer,
              if: proc { expand?('shipping_category') }

          one :tax_category,
              resource: Spree.api.admin_tax_category_serializer,
              if: proc { expand?('tax_category') }
        end
      end
    end
  end
end
