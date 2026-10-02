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

          typelize status: [:string, enum: Spree::Product.statuses, enum_type_name: 'ProductStatus'],
                   tax_category_id: [:string, nullable: true],
                   product_type_id: [:string, nullable: true],
                   delivery_profile_id: [:string, nullable: true],
                   seller_name: [:string, nullable: true],
                   price: ['Price', nullable: true],
                   deleted_at: [:string, nullable: true],
                   metadata: 'Record<string, unknown>',
                   submission: ['ProductSubmission', nullable: true]

          attributes :status,
                     :metadata, deleted_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          prefixed_id_attributes :delivery_profile

          # The live row in the review trail: who submitted, who decided,
          # when, and what the seller was told. Expanded rather than always
          # sent — it is a per-product query that the index has no use for.
          one :latest_submission,
              key: :submission,
              resource: proc { Spree.api.admin_product_submission_serializer },
              if: proc { expand?('submission') }

          # `seller_id` comes from the store serializer. The name rides along
          # so the products list can show who sells a row without expanding —
          # the full profile is `?expand=seller`.
          attribute :seller_name do |product|
            product.seller&.name
          end

          expandable :one, :seller, :admin_seller_serializer

          prefixed_id_attributes :product_type, :tax_category

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
          expandable :many, :variants, :admin_variant_serializer

          expandable :one, :default_variant, :admin_variant_serializer

          expandable :one, :primary_media, :admin_media_serializer

          many :gallery_media,
               key: :media,
               resource: proc { Spree.api.admin_media_serializer },
               if: proc { expand?('media') }

          # Read/write symmetry: the product accepts inline `digital_assets` on
          # create, so it exposes them (opt-in via ?expand=digital_assets).
          expandable :many, :digital_assets, :admin_digital_asset_serializer

          expandable :many, :option_types, :admin_option_type_serializer

          expandable :many, :option_values, :admin_option_value_serializer

          many :categories,
               proc { |categories, params|
                 store_id = params[:store].id
                 categories.select { |c| c.store_id == store_id }
               },
               resource: proc { Spree.api.admin_category_serializer },
               if: proc { expand?('categories') }

          expandable :many, :collections, :admin_collection_serializer

          expandable :many, :custom_fields, :admin_custom_field_serializer

          expandable :many, :product_publications, :admin_product_publication_serializer

          expandable :many, :channels, :admin_channel_serializer

          expandable :one, :product_type, :admin_product_type_serializer
        end
      end
    end
  end
end
