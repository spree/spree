module Spree
  module Api
    module V3
      module Admin
        # Inventory movement between two stock locations (or external →
        # location for receives). The originating location is `nil` for
        # receives (vendor stock arriving) and present for transfers.
        class StockTransferSerializer < V3::BaseSerializer
          typelize number: :string,
                   reference: [:string, nullable: true],
                   source_location_id: [:string, nullable: true],
                   destination_location_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :number, :reference, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :source_location_id do |stock_transfer|
            stock_transfer.source_location&.prefixed_id
          end

          attribute :destination_location_id do |stock_transfer|
            stock_transfer.destination_location&.prefixed_id
          end

          one :source_location,
              resource: proc { Spree.api.admin_stock_location_serializer },
              if: proc { expand?('source_location') }

          one :destination_location,
              resource: proc { Spree.api.admin_stock_location_serializer },
              if: proc { expand?('destination_location') }
        end
      end
    end
  end
end
