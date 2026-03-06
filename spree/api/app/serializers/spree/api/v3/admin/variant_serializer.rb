module Spree
  module Api
    module V3
      module Admin
        # Admin API Variant Serializer
        # Full variant data including admin-only fields
        class VariantSerializer < V3::VariantSerializer

          # Additional type hints for admin-only attributes
          # Override price/original_price to reference AdminPrice instead of StorePrice
          typelize position: :number, tax_category_id: [:string, nullable: true],
                   cost_price: [:string, nullable: true], cost_currency: [:string, nullable: true],
                   total_on_hand: [:number, nullable: true],
                   deleted_at: [:string, nullable: true],
                   price: 'AdminPrice', original_price: ['AdminPrice', nullable: true]

          # Admin-only attributes
          attributes :position, :tax_category_id, :cost_price, :cost_currency, deleted_at: :iso8601

          attribute :total_on_hand do |variant|
            variant.total_on_hand
          end

          # Override price/original_price to use admin price serializer
          attribute :price do |variant|
            price = price_for(variant)
            Spree.api.admin_price_serializer.new(price, params: params).to_h if price.present?
          end

          attribute :original_price do |variant|
            calculated = price_for(variant)
            base = price_in(variant)

            if calculated.present? && base.present? && calculated.id != base.id
              Spree.api.admin_price_serializer.new(base, params: params).to_h
            end
          end

          # Override all nested associations to use admin serializers
          many :images,
               resource: Spree.api.admin_image_serializer,
               if: proc { expand?('images') }

          many :option_values, resource: Spree.api.admin_option_value_serializer

          many :prices,
               resource: Spree.api.admin_price_serializer,
               if: proc { expand?('prices') }

          many :stock_items,
               resource: Spree.api.admin_stock_item_serializer,
               if: proc { expand?('stock_items') }

          many :metafields,
               resource: Spree.api.admin_metafield_serializer,
               if: proc { expand?('metafields') }
        end
      end
    end
  end
end
