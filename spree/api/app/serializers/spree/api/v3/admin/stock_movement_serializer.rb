module Spree
  module Api
    module V3
      module Admin
        class StockMovementSerializer < V3::StockMovementSerializer
          typelize order_id: [:string, nullable: true], fulfillment_id: [:string, nullable: true],
                   return_id: [:string, nullable: true], exchange_id: [:string, nullable: true],
                   stock_transfer_id: [:string, nullable: true],
                   purchase_order_id: [:string, nullable: true],
                   unit_cost: [:string, nullable: true],
                   display_unit_cost: [:string, nullable: true],
                   stock_location_id: [:string, nullable: true],
                   stock_location_name: [:string, nullable: true],
                   variant_id: [:string, nullable: true],
                   variant_name: [:string, nullable: true],
                   variant_sku: [:string, nullable: true]

          # Which shelf, and which SKU. A movement names neither directly —
          # both hang off its stock level, the (variant, warehouse) pair — but
          # a history panel cannot be read without them: scoped to a variant
          # the warehouse is what varies, scoped to a warehouse the SKU is,
          # and scoped to one transfer both do.
          attribute :stock_location_id do |movement|
            movement.stock_level&.stock_location&.prefixed_id
          end

          attribute :stock_location_name do |movement|
            movement.stock_level&.stock_location&.name
          end

          attribute :variant_id do |movement|
            movement.stock_level&.variant&.prefixed_id
          end

          attribute :variant_name do |movement|
            movement.stock_level&.variant&.product&.name
          end

          attribute :variant_sku do |movement|
            movement.stock_level&.variant&.sku
          end

          # The cause. Exactly which keys are set follows from the kind — a
          # dispatch carries its fulfillment and its order, a transfer carries
          # the transfer, a correction carries none.
          attribute :order_id do |movement|
            Spree::Order.prefixed_id_for(movement.order_id)
          end

          attribute :fulfillment_id do |movement|
            Spree::Fulfillment.prefixed_id_for(movement.fulfillment_id)
          end

          attribute :return_id do |movement|
            Spree::Return.prefixed_id_for(movement.return_id)
          end

          attribute :exchange_id do |movement|
            Spree::Exchange.prefixed_id_for(movement.exchange_id)
          end

          attribute :stock_transfer_id do |movement|
            Spree::StockTransfer.prefixed_id_for(movement.stock_transfer_id)
          end

          attribute :purchase_order_id do |movement|
            Spree::PurchaseOrder.prefixed_id_for(movement.purchase_order_id)
          end

          # What the units cost, on the rows where that means something: a
          # purchase. Null on a transfer or a return — moving stock the
          # merchant already owns is not buying it.
          attribute :unit_cost do |movement|
            movement.unit_cost&.to_s
          end

          attribute :display_unit_cost do |movement|
            movement.display_unit_cost&.to_s
          end
        end
      end
    end
  end
end
