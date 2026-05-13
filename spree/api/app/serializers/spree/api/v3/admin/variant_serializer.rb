module Spree
  module Api
    module V3
      module Admin
        # Admin API Variant Serializer
        # Full variant data including admin-only fields
        class VariantSerializer < V3::VariantSerializer

          typelize product_name: :string,
                   position: :number, tax_category_id: [:string, nullable: true],
                   cost_price: [:string, nullable: true], cost_currency: [:string, nullable: true],
                   barcode: [:string, nullable: true],
                   weight_unit: [:string, nullable: true], dimensions_unit: [:string, nullable: true],
                   available_stock: [:number, nullable: true],
                   reserved_quantity: :number, total_on_hand: [:number, nullable: true],
                   deleted_at: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :metadata, :position, :cost_price, :cost_currency,
                     :barcode, :weight_unit, :dimensions_unit, deleted_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :tax_category_id do |variant|
            variant.tax_category&.prefixed_id
          end

          # Physical pool minus already-allocated units. In 5.5 allocated_count
          # is always 0, so this equals SUM(stock_items.count_on_hand).
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

          # Override inherited associations to use admin serializers
          one :primary_media,
              resource: Spree.api.admin_media_serializer,
              if: proc { expand?('primary_media') }

          many :gallery_media,
               key: :media,
               resource: Spree.api.admin_media_serializer,
               if: proc { expand?('media') }

          many :option_values, resource: Spree.api.admin_option_value_serializer

          # All prices for this variant (for admin management)
          many :prices,
               resource: Spree.api.admin_price_serializer,
               if: proc { expand?('prices') }

          many :metafields,
               key: :custom_fields,
               resource: Spree.api.admin_custom_field_serializer,
               if: proc { expand?('custom_fields') }

          many :stock_items,
               resource: Spree.api.admin_stock_item_serializer,
               if: proc { expand?('stock_items') }
        end
      end
    end
  end
end
