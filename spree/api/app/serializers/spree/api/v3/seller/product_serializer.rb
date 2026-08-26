module Spree
  module Api
    module V3
      module Seller
        # A seller's own product.
        #
        # Read and write have to name the same fields: the panel loads a
        # product into a form and sends it back, so anything the controller
        # accepts but this withholds would be blanked on save.
        #
        # `category_ids` is a flat list rather than the operator's expandable
        # association — the form binds ids, and a seller has no use for the
        # rest of a category.
        class ProductSerializer < V3::ProductSerializer
          typelize status: :string,
                   product_type_id: [:string, nullable: true],
                   category_ids: [:string, multi: true],
                   collection_ids: [:string, multi: true],
                   metadata: 'Record<string, unknown>'

          attributes :status, :metadata, created_at: :iso8601, updated_at: :iso8601

          attribute :product_type_id do |product|
            product.product_type&.prefixed_id
          end

          attribute :category_ids do |product|
            store_id = current_store&.id
            product.categories.filter_map do |category|
              category.prefixed_id if store_id.nil? || category.store_id == store_id
            end
          end

          attribute :collection_ids do |product|
            product.collections.map(&:prefixed_id)
          end

          many :variants,
               resource: proc { Spree.api.seller_variant_serializer },
               if: proc { expand?('variants') }

          one :default_variant,
              resource: proc { Spree.api.seller_variant_serializer },
              if: proc { expand?('default_variant') }

          many :gallery_media,
               key: :media,
               resource: proc { Spree.api.seller_media_serializer },
               if: proc { expand?('media') }

          many :option_types,
               resource: proc { Spree.api.option_type_serializer },
               if: proc { expand?('option_types') }

          many :custom_fields,
               resource: proc { Spree.api.seller_custom_field_serializer },
               if: proc { expand?('custom_fields') }
        end
      end
    end
  end
end
