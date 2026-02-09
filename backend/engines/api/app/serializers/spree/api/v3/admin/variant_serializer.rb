module Spree
  module Api
    module V3
      module Admin
        # Admin API Variant Serializer
        # Full variant data including admin-only fields
        class VariantSerializer < V3::VariantSerializer

          # Additional type hints for admin-only attributes
          typelize position: :number, tax_category_id: 'string | null',
                   cost_price: 'number | null', cost_currency: 'string | null',
                   total_on_hand: 'number | null',
                   deleted_at: 'string | null'

          # Admin-only attributes
          attributes :position, :tax_category_id, deleted_at: :iso8601

          attribute :cost_price do |variant|
            variant.cost_price&.to_f
          end

          attribute :cost_currency do |variant|
            variant.cost_currency
          end

          attribute :total_on_hand do |variant|
            variant.total_on_hand
          end

          # All prices for this variant (for admin management)
          many :prices,
               resource: Spree::Api::V3::Admin::PriceSerializer,
               if: proc { params[:includes]&.include?('prices') }

          many :metafields,
               resource: Spree::Api::V3::Admin::MetafieldSerializer,
               if: proc { params[:includes]&.include?('metafields') }

          # TODO: Add stock_items association when Admin API is implemented
        end
      end
    end
  end
end
