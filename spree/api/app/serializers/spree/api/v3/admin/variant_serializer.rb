module Spree
  module Api
    module V3
      module Admin
        # Admin API Variant Serializer
        # Full variant data including admin-only fields
        class VariantSerializer < V3::VariantSerializer

          # Additional type hints for admin-only attributes
          typelize position: :number, tax_category_id: [:string, nullable: true],
                   cost_price: [:string, nullable: true], cost_currency: [:string, nullable: true],
                   total_on_hand: [:number, nullable: true],
                   deleted_at: [:string, nullable: true]

          # Admin-only attributes
          attributes :position, :tax_category_id, :cost_price, :cost_currency, deleted_at: :iso8601

          attribute :total_on_hand do |variant|
            variant.total_on_hand
          end

          # Override inherited associations to use admin serializers
          many :images,
               resource: Spree.api.admin_image_serializer,
               if: proc { expand?('images') }

          many :option_values, resource: Spree.api.admin_option_value_serializer

          # All prices for this variant (for admin management)
          many :prices,
               resource: Spree.api.admin_price_serializer,
               if: proc { expand?('prices') }

          many :metafields,
               resource: Spree.api.admin_metafield_serializer,
               if: proc { expand?('metafields') }
        end
      end
    end
  end
end
