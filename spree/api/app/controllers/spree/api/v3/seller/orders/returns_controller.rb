module Spree
  module Api
    module V3
      module Seller
        module Orders
          # Goods coming back on one of this seller's orders.
          #
          # Every status move reuses the operator's workflow, shared through
          # the concern, so restocking, the tax credit, the refund and the
          # ledger reversal all happen exactly as they do when the marketplace
          # handles the return itself. What is here is what makes it the
          # seller's: the order comes from `current_seller_orders`, so a
          # return on somebody else's order reads as missing rather than
          # denied, and the goods go back onto the seller's own shelf.
          class ReturnsController < BaseController
            include Spree::Api::V3::Orders::ReturnActions

            before_action :set_resource, only: [:show, :approve, :receive, :refund, :cancel]

            request_params :return do
              object :items, array: true, required: true do
                id :fulfillment_item_id, required: true
                integer :quantity, required: true
              end
              id :reason_id, nullable: true
              id :stock_location_id, nullable: true, description: "One of this seller's own stock locations, where the goods are restocked."
              string :memo, nullable: true
            end

            request_params 'ReturnReceiveParams', action: :receive do
              object :items, array: true, description: 'What actually arrived. Omit to receive everything as requested and resellable.' do
                id :return_line_item_id, required: true
                integer :quantity, required: true
                boolean :resellable, description: 'Defaults to true.'
              end
            end

            request_params 'ReturnRefundParams', action: :refund do
              decimal :amount, nullable: true
              string :refund_method, enum: %w[original_payment store_credit], description: 'Defaults to `original_payment`.'
            end

            request_params 'ReturnCancelParams', action: :cancel do
              string :reason, description: 'A note on why the return was canceled.'
            end

            protected

            def serializer_class
              Spree.api.seller_return_serializer
            end

            def collection_includes
              [:reason, :stock_location, { return_line_items: [:variant, :line_item] }]
            end

            private

            # The seller's own shelves: returned goods go back into the stock
            # the seller sells from, never a marketplace warehouse.
            def stock_location_for_create
              return nil if create_params[:stock_location_id].blank?

              current_seller.stock_locations.find_by_prefix_id!(create_params[:stock_location_id])
            end
          end
        end
      end
    end
  end
end
