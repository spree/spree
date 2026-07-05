module Spree
  module Api
    module V3
      module Admin
        class StockReservationSerializer < V3::StockReservationSerializer
          typelize stock_item_id: :string,
                   line_item_id: :string,
                   order_id: :string,
                   variant_id: [:string, nullable: true],
                   stock_location_id: [:string, nullable: true],
                   quantity: :number,
                   expires_at: :string,
                   active: :boolean

          attribute :stock_item_id do |reservation|
            reservation.stock_item.prefixed_id
          end

          attribute :line_item_id do |reservation|
            reservation.line_item.prefixed_id
          end

          attribute :order_id do |reservation|
            reservation.order.prefixed_id
          end

          attribute :variant_id do |reservation|
            reservation.stock_item&.variant&.prefixed_id
          end

          attribute :stock_location_id do |reservation|
            reservation.stock_item&.stock_location&.prefixed_id
          end

          attributes :quantity, expires_at: :iso8601

          attribute :active do |reservation|
            reservation.active?
          end

          attributes created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
