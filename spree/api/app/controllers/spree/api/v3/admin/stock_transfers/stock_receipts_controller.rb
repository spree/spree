module Spree
  module Api
    module V3
      module Admin
        module StockTransfers
          # The deliveries the destination warehouse counted in against one
          # transfer. Recording one lands the accepted units on its shelf.
          class StockReceiptsController < ResourceController
            include Spree::Api::V3::Admin::StockReceiptActions

            scoped_resource :stock

            protected

            def set_parent
              @parent = current_store.stock_transfers.find_by_prefix_id!(params[:stock_transfer_id])
            end

            def create_workflow
              Spree.stock_transfer_receive_workflow
            end

            def receivable_keyword
              :stock_transfer
            end
          end
        end
      end
    end
  end
end
