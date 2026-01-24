module Spree
  module Api
    module V3
      module Admin
        # Admin API Variant Serializer
        # Full variant data including admin-only fields
        class VariantSerializer < V3::VariantSerializer
          typelize_from Spree::Variant

          # Additional type hints for admin-only attributes
          typelize cost_price: 'number | null', cost_currency: 'string | null',
                   total_on_hand: 'number | null',
                   public_metadata: 'Record<string, unknown> | null',
                   private_metadata: 'Record<string, unknown> | null',
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

          attribute :public_metadata do |variant|
            variant.public_metadata
          end

          attribute :private_metadata do |variant|
            variant.private_metadata
          end

          # TODO: Add stock_items and prices associations when Admin API is implemented
        end
      end
    end
  end
end
