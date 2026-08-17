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
                   preorderable: :boolean, preorder_ships_at: [:string, nullable: true],
                   backorder_limit: [:number, nullable: true],
                   hs_code: [:string, nullable: true],
                   country_of_origin: [:string, nullable: true],
                   customs_description: [:string, nullable: true],
                   deleted_at: [:string, nullable: true],
                   seller_name: [:string, nullable: true],
                   delivery_profile_id: [:string, nullable: true],
                   own_delivery_profile_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :metadata, :position, :cost_price, :cost_currency,
                     :barcode, :weight_unit, :dimensions_unit, :backorder_limit,
                     :hs_code, :country_of_origin, :customs_description,
                     preorder_ships_at: :iso8601, deleted_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :preorderable do |variant|
            variant.preorderable?
          end

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

          # `seller_id` comes from the store serializer. The name rides along
          # so the variants table can show a seller column without an expand.
          attribute :seller_name do |variant|
            variant.seller&.name
          end

          # Two answers, because they mean different things. `delivery_profile_id`
          # is what the variant actually ships on, resolved through the product.
          # `own_delivery_profile_id` is the override itself — the writable one,
          # so an editor can tell "inherits" from "deliberately set to the same
          # profile", and clear it back to inheriting by writing nil.
          #
          # Reading the resolved value under the writable name is what would
          # freeze an inherited profile into an override on the first round-trip
          # save, which is precisely what a variant-level override must not do.
          attribute :delivery_profile_id do |variant|
            variant.delivery_profile&.prefixed_id
          end

          attribute :own_delivery_profile_id do |variant|
            variant.association(:delivery_profile).reader&.prefixed_id if variant.own_delivery_profile_id
          end

          one :seller,
              resource: proc { Spree.api.admin_seller_serializer },
              if: proc { expand?('seller') }

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

          many :stock_items,
               resource: proc { Spree.api.admin_stock_item_serializer },
               if: proc { expand?('stock_items') }
        end
      end
    end
  end
end
