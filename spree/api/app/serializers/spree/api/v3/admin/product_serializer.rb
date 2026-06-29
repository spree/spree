module Spree
  module Api
    module V3
      module Admin
        # Admin API Product Serializer
        # Full product data including admin-only fields
        # Extends the store serializer with additional attributes
        class ProductSerializer < V3::ProductSerializer

          typelize status: :string,
                   tax_category_id: [:string, nullable: true],
                   price: ['Price', nullable: true],
                   deleted_at: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :status,
                     :metadata, deleted_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :tax_category_id do |product|
            product.tax_category&.prefixed_id
          end

          attribute :price do |product|
            price = price_for(product.default_variant)
            Spree.api.admin_price_serializer.new(price, params: params).to_h if price&.persisted?
          end

          attribute :original_price do |product|
            variant = product.default_variant
            calculated = price_for(variant)
            base = price_in(variant)

            if calculated.present? && base.present? && calculated.id != base.id
              Spree.api.admin_price_serializer.new(base, params: params).to_h
            end
          end

          # Admin uses admin variant serializer
          many :variants,
               resource: proc { Spree.api.admin_variant_serializer },
               if: proc { expand?('variants') }

          one :default_variant,
              resource: proc { Spree.api.admin_variant_serializer },
              if: proc { expand?('default_variant') }

          one :primary_media,
              resource: proc { Spree.api.admin_media_serializer },
              if: proc { expand?('primary_media') }

          many :gallery_media,
               key: :media,
               resource: proc { Spree.api.admin_media_serializer },
               if: proc { expand?('media') }

          many :option_types,
               resource: proc { Spree.api.admin_option_type_serializer },
               if: proc { expand?('option_types') }

          many :option_values,
               resource: proc { Spree.api.admin_option_value_serializer },
               if: proc { expand?('option_values') }

          many :taxons,
               proc { |taxons, params|
                 taxons.select { |t| t.taxonomy.store_id == params[:store].id }
               },
               key: :categories,
               resource: proc { Spree.api.admin_category_serializer },
               if: proc { expand?('categories') }

          many :metafields,
               key: :custom_fields,
               resource: proc { Spree.api.admin_custom_field_serializer },
               if: proc { expand?('custom_fields') }

          many :product_publications,
               resource: proc { Spree.api.admin_product_publication_serializer },
               if: proc { expand?('product_publications') }

          many :channels,
               resource: proc { Spree.api.admin_channel_serializer },
               if: proc { expand?('channels') }
        end
      end
    end
  end
end
