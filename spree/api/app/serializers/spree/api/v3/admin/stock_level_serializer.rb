module Spree
  module Api
    module V3
      module Admin
        class StockLevelSerializer < V3::StockLevelSerializer
          include Concerns::ExternalReferencesAttribute

          typelize metadata: 'Record<string, unknown>',
                   allocated_count: :number, available_count: :number,
                   reserved_count: :number, incoming_count: :number,
                   stock_location_name: [:string, nullable: true],
                   product_id: [:string, nullable: true],
                   variant_name: [:string, nullable: true], variant_sku: [:string, nullable: true],
                   options_text: [:string, nullable: true],
                   thumbnail_url: [:string, nullable: true]

          # Reserved: units held by checkouts in progress. Incoming: units on
          # their way on an open purchase order or a transfer in transit.
          attributes :metadata, :reserved_count, :incoming_count,
                     created_at: :iso8601, updated_at: :iso8601

          # Which shelf and which SKU, flat, the way a stock movement names
          # them: enough for a list row without expanding the variant, whose
          # own serializer computes availability per row.
          attribute :stock_location_name do |stock_level|
            stock_level.stock_location&.name
          end

          attribute :product_id do |stock_level|
            stock_level.variant&.product&.prefixed_id
          end

          attribute :variant_name do |stock_level|
            stock_level.variant&.product&.name
          end

          attribute :variant_sku do |stock_level|
            stock_level.variant&.sku
          end

          attribute :options_text do |stock_level|
            stock_level.variant&.options_text.presence
          end

          attribute :thumbnail_url do |stock_level|
            image_url_for(stock_level.thumbnail)
          end

          # Units promised to placed orders but not yet dispatched. Raised by an
          # `allocated` movement and retired by `released` or `shipped`, so an
          # oversell reads as this exceeding count_on_hand.
          attribute :allocated_count do |stock_level|
            stock_level.allocated_count.to_i
          end

          # Physical stock minus allocated units (per stock_level).
          attribute :available_count do |stock_level|
            stock_level.available_count.to_i
          end

          one :stock_location,
              resource: proc { Spree.api.admin_stock_location_serializer },
              if: proc { expand?('stock_location') }

          one :variant,
              resource: proc { Spree.api.admin_variant_serializer },
              if: proc { expand?('variant') }
        end
      end
    end
  end
end
