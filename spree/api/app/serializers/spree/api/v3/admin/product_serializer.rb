module Spree
  module Api
    module V3
      module Admin
        # Admin API Product Serializer
        # Full product data including admin-only fields
        # Extends the store serializer with additional attributes
        class ProductSerializer < V3::ProductSerializer
          include Concerns::ExternalReferencesAttribute

          include Spree::Api::V3::Admin::Translatable

          typelize status: :string,
                   tax_category_id: [:string, nullable: true],
                   product_type_id: [:string, nullable: true],
                   delivery_profile_id: [:string, nullable: true],
                   seller_name: [:string, nullable: true],
                   price: ['Price', nullable: true],
                   deleted_at: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :status,
                     :metadata, deleted_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :delivery_profile_id do |product|
            product.delivery_profile&.prefixed_id
          end

          # `seller_id` comes from the store serializer. The name rides along
          # so the products list can show who sells a row without expanding —
          # the full profile is `?expand=seller`.
          attribute :seller_name do |product|
            product.seller&.name
          end

          one :seller,
              resource: proc { Spree.api.admin_seller_serializer },
              if: proc { expand?('seller') }

          attribute :product_type_id do |product|
            product.product_type&.prefixed_id
          end

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

          many :categories,
               proc { |categories, params|
                 store_id = params[:store].id
                 categories.select { |c| c.store_id == store_id }
               },
               resource: proc { Spree.api.admin_category_serializer },
               if: proc { expand?('categories') }

          many :collections,
               resource: proc { Spree.api.admin_collection_serializer },
               if: proc { expand?('collections') }

          many :custom_fields,
               resource: proc { Spree.api.admin_custom_field_serializer },
               if: proc { expand?('custom_fields') }

          many :product_publications,
               resource: proc { Spree.api.admin_product_publication_serializer },
               if: proc { expand?('product_publications') }

          many :channels,
               resource: proc { Spree.api.admin_channel_serializer },
               if: proc { expand?('channels') }

          one :product_type,
              resource: proc { Spree.api.admin_product_type_serializer },
              if: proc { expand?('product_type') }
        end
      end
    end
  end
end
