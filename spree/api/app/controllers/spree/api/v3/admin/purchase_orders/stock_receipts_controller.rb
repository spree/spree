module Spree
  module Api
    module V3
      module Admin
        module PurchaseOrders
          # The deliveries booked against one purchase order. Recording one
          # is how the order is received: this is the moment purchased goods
          # first count toward availability.
          class StockReceiptsController < ResourceController
            include Spree::Api::V3::Admin::StockReceiptActions

            scoped_resource :purchasing

            protected

            def set_parent
              @parent = current_store.purchase_orders.find_by_prefix_id!(params[:purchase_order_id])
            end

            def create_workflow
              Spree.purchase_order_receive_workflow
            end

            def receivable_keyword
              :purchase_order
            end
          end
        end
      end
    end
  end
end
