module Spree
  module Api
    module V3
      module Seller
        # A seller's own product.
        #
        # Read and write have to name the same fields: the panel loads a
        # product into a form and sends it back, so anything the controller
        # accepts but this withholds would be blanked on save. The reverse
        # matters too — how a product is filed (categories, collections, tags)
        # is the marketplace's own merchandising, so it is neither written nor
        # read here. The type and the delivery profile are: a seller picks
        # both from the marketplace's list
        # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
        class ProductSerializer < V3::ProductSerializer
          typelize status: :string, metadata: 'Record<string, unknown>',
                   product_type_id: [:string, nullable: true],
                   delivery_profile_id: [:string, nullable: true],
                   submission: ['ProductSubmission', nullable: true]

          attributes :status, :metadata, created_at: :iso8601, updated_at: :iso8601

          attribute :product_type_id do |product|
            product.product_type&.prefixed_id
          end

          attribute :delivery_profile_id do |product|
            product.delivery_profile&.prefixed_id
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

          # Why the marketplace sent this back, so the panel can show it
          # against a rejected listing without a second request. Expanded
          # rather than always sent — it is a per-product query, and the
          # products list has no use for it.
          one :latest_submission,
              key: :submission,
              resource: proc { Spree.api.product_submission_serializer },
              if: proc { expand?('submission') }
        end
      end
    end
  end
end
