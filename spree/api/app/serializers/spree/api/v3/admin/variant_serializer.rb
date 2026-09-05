module Spree
  module Api
    module V3
      module Admin
        # Admin API Variant Serializer
        # Full variant data including admin-only fields
        class VariantSerializer < V3::VariantSerializer
          include Concerns::ExternalReferencesAttribute


          typelize product_name: :string,
                   position: :number, tax_category_id: [:string, nullable: true],
                   cost_price: [:string, nullable: true], cost_currency: [:string, nullable: true],
                   barcode: [:string, nullable: true],
                   weight_unit: [:string, nullable: true], dimensions_unit: [:string, nullable: true],
                   available_stock: [:number, nullable: true],
                   reserved_quantity: :number, total_on_hand: [:number, nullable: true],
                   preorderable: :boolean, preorder_ships_at: [:string, nullable: true],
                   backorder_limit: [:number, nullable: true],
                   hs_code: [:string, nullable: true],
                   country_of_origin: [:string, nullable: true],
                   customs_description: [:string, nullable: true],
                   deleted_at: [:string, nullable: true],
                   status: :string,
                   submission: ['ProductSubmission', nullable: true],
                   delivery_profile_id: [:string, nullable: true],
                   minimum_order_quantity: ['number | null'], order_multiple: ['number | null'],
                   purchase_unit: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          # The last three override the store serializer's buyer-resolved
          # values with the variant's OWN: a merchant edits what is stored on
          # the row, not what some catalog resolves to for a buyer they are not.
          attributes :status,
                     :metadata, :position, :cost_price, :cost_currency,
                     :barcode, :weight_unit, :dimensions_unit, :backorder_limit,
                     :hs_code, :country_of_origin, :customs_description,
                     :minimum_order_quantity, :order_multiple, :purchase_unit,
                     preorder_ships_at: :iso8601, deleted_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :preorderable do |variant|
            variant.preorderable?
          end

          attribute :tax_category_id do |variant|
            variant.tax_category&.prefixed_id
          end

          # Physical pool minus already-allocated units. In 5.5 allocated_count
          # is always 0, so this equals SUM(stock_levels.count_on_hand).
          attribute :available_stock do |variant|
            variant.available_stock.to_i if variant.should_track_inventory?
          end

          attribute :reserved_quantity do |variant|
            variant.reserved_quantity.to_i
          end

          # Purchasable now: available_stock minus active reservations.
          attribute :total_on_hand do |variant|
            variant.total_on_hand.to_i if variant.should_track_inventory?
          end

          attribute :product_name do |variant|
            variant.product&.name
          end

          # How this variant ships — one answer, resolved on the model the same
          # way the seller is. Writable: on a master product it names how this
          # seller's row ships; on an owned product the write is a no-op, since
          # every variant ships as the product does. The dashboard need not
          # know which.
          attribute :delivery_profile_id do |variant|
            variant.resolved_delivery_profile&.prefixed_id
          end

          one :seller,
              resource: proc { Spree.api.admin_seller_serializer },
              if: proc { expand?('seller') } do |variant|
            variant.resolved_seller
          end

          # The live row in this offer's review trail — who submitted, who
          # decided, when, and what the seller was told. Nil on a first-party
          # row, which nobody reviews
          # (docs/plans/6.0-seller-master-catalog-listings.md).
          one :latest_submission,
              key: :submission,
              resource: proc { Spree.api.admin_product_submission_serializer },
              if: proc { expand?('submission') }

          # Override inherited associations to use admin serializers
          one :primary_media,
              resource: proc { Spree.api.admin_media_serializer },
              if: proc { expand?('primary_media') }

          many :gallery_media,
               key: :media,
               resource: proc { Spree.api.admin_media_serializer },
               if: proc { expand?('media') }

          many :option_values, resource: proc { Spree.api.admin_option_value_serializer }

          # All prices for this variant (for admin management)
          many :prices,
               resource: proc { Spree.api.admin_price_serializer },
               if: proc { expand?('prices') }

          many :custom_fields,
               resource: proc { Spree.api.admin_custom_field_serializer },
               if: proc { expand?('custom_fields') }

          many :stock_levels,
               resource: proc { Spree.api.admin_stock_level_serializer },
               if: proc { expand?('stock_levels') }
        end
      end
    end
  end
end
