module Spree
  module Api
    module V3
      module Seller
        # One variant of a seller's own product.
        #
        # Carries what a seller manages: the SKU and barcode, what it cost
        # them, its weight and dimensions, its customs classification and what
        # is on the shelf. No `tax_category_id` — that is marketplace
        # configuration and the seller cannot write it, so showing it would
        # invite an edit that silently does nothing.
        #
        # `delivery_profile_id` IS here: on an offer against a master product
        # it names how that seller's row ships, which is the seller's own
        # choice from the marketplace's list. On a variant of a product the
        # seller owns, the model blanks it and the write is a no-op, so the
        # panel need not know which mode it is in
        # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 10).
        class VariantSerializer < V3::VariantSerializer
          typelize status: :string,
                   product_id: :string,
                   delivery_profile_id: [:string, nullable: true],
                   submission: ['ProductSubmission', nullable: true],
                   position: :number,
                   cost_price: [:string, nullable: true],
                   cost_currency: [:string, nullable: true],
                   barcode: [:string, nullable: true],
                   weight_unit: [:string, nullable: true],
                   dimensions_unit: [:string, nullable: true],
                   available_stock: [:number, nullable: true],
                   total_on_hand: [:number, nullable: true],
                   preorderable: :boolean,
                   preorder_ships_at: [:string, nullable: true],
                   backorder_limit: [:number, nullable: true],
                   hs_code: [:string, nullable: true],
                   country_of_origin: [:string, nullable: true],
                   customs_description: [:string, nullable: true],
                   minimum_order_quantity: ['number | null'], order_multiple: ['number | null'],
                   purchase_unit: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :status,
                     :metadata, :position, :cost_price, :cost_currency,
                     :barcode, :weight_unit, :dimensions_unit, :backorder_limit,
                     :hs_code, :country_of_origin, :customs_description,
                     preorder_ships_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          # The variant's own stored rules, not a buyer's resolved ones — a
          # seller edits the row.
          attribute :minimum_order_quantity, &:minimum_order_quantity
          attribute :order_multiple, &:order_multiple
          attribute :purchase_unit, &:purchase_unit

          attribute :preorderable, &:preorderable?

          # Which product this offer sits on, so the offers list can name it
          # without a second request.
          attribute :product_id do |variant|
            variant.product&.prefixed_id
          end

          # Read resolved and written to the column, exactly as on the admin
          # serializer: a read-then-write round trip on an owned variant
          # therefore changes nothing.
          attribute :delivery_profile_id do |variant|
            variant.resolved_delivery_profile&.prefixed_id
          end

          # Why the marketplace sent this offer back, so the panel can show it
          # without a second request. The seller's view withholds who decided.
          one :latest_submission,
              key: :submission,
              resource: proc { Spree.api.product_submission_serializer },
              if: proc { expand?('submission') }

          # The product this offer is against, for the offers list's name and
          # thumbnail. The public serializer: what one seller may know about
          # the marketplace's catalog is what a shopper may know.
          one :product,
              resource: proc { Spree.api.product_serializer },
              if: proc { expand?('product') }

          attribute :available_stock do |variant|
            variant.available_stock.to_i if variant.should_track_inventory?
          end

          attribute :total_on_hand do |variant|
            variant.total_on_hand.to_i if variant.should_track_inventory?
          end

          one :primary_media,
              resource: proc { Spree.api.seller_media_serializer },
              if: proc { expand?('primary_media') }

          many :gallery_media,
               key: :media,
               resource: proc { Spree.api.seller_media_serializer },
               if: proc { expand?('media') }

          many :prices,
               resource: proc { Spree.api.price_serializer },
               if: proc { expand?('prices') }

          many :stock_levels,
               resource: proc { Spree.api.seller_stock_level_serializer },
               if: proc { expand?('stock_levels') }
        end
      end
    end
  end
end
