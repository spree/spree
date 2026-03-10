module Spree
  module Api
    module V3
      module Admin
        # Admin API Product Serializer
        # Full product data including admin-only fields
        # Extends the store serializer with additional attributes
        class ProductSerializer < V3::ProductSerializer

          # Additional type hints for admin-only computed attributes
          typelize status: :string, make_active_at: [:string, nullable: true], discontinue_on: [:string, nullable: true],
                   cost_price: [:string, nullable: true], cost_currency: [:string, nullable: true],
                   deleted_at: [:string, nullable: true]

          # Admin-only attributes
          attributes :status, :make_active_at, :discontinue_on, deleted_at: :iso8601

          attribute :cost_price do |product|
            product.master&.cost_price
          end

          attribute :cost_currency do |product|
            product.master&.cost_currency
          end

          # Admin uses admin variant serializer
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

          many :variant_images,
               key: :images,
               resource: Spree.api.admin_image_serializer,
               if: proc { expand?('images') }

          many :option_types,
               resource: Spree.api.admin_option_type_serializer,
               if: proc { expand?('option_types') }

          many :taxons,
               proc { |taxons, params|
                 taxons.select { |t| t.taxonomy.store_id == params[:store].id }
               },
               key: :categories,
               resource: Spree.api.admin_category_serializer,
               if: proc { expand?('categories') }

          many :metafields,
               resource: Spree.api.admin_metafield_serializer,
               if: proc { expand?('metafields') }
        end
      end
    end
  end
end
