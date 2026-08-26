module Spree
  module Api
    module V3
      module Seller
        # One variant of a seller's own product.
        #
        # Carries what a seller manages: the SKU and barcode, what it cost
        # them, its weight and dimensions, its customs classification and what
        # is on the shelf. No `tax_category_id` or `delivery_profile_id` —
        # those are marketplace configuration and the seller cannot write them,
        # so showing them would invite an edit that silently does nothing.
        class VariantSerializer < V3::VariantSerializer
          typelize position: :number,
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
                   metadata: 'Record<string, unknown>'

          attributes :metadata, :position, :cost_price, :cost_currency,
                     :barcode, :weight_unit, :dimensions_unit, :backorder_limit,
                     :hs_code, :country_of_origin, :customs_description,
                     preorder_ships_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :preorderable, &:preorderable?

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

          many :custom_fields,
               resource: proc { Spree.api.seller_custom_field_serializer },
               if: proc { expand?('custom_fields') }

          many :stock_levels,
               resource: proc { Spree.api.seller_stock_level_serializer },
               if: proc { expand?('stock_levels') }
        end
      end
    end
  end
end
