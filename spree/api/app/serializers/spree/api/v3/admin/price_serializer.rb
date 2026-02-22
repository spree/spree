module Spree
  module Api
    module V3
      module Admin
        # Admin API Price Serializer
        # Extends Store Price Serializer with admin-only fields
        class PriceSerializer < V3::PriceSerializer
          typelize variant_id: [:string, nullable: true],
                   created_at: :string,
                   updated_at: :string

          attribute :variant_id do |price|
            price&.variant&.prefixed_id
          end

          attributes created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
