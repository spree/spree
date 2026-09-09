module Spree
  module Api
    module V3
      module Admin
        module Sellers
          # Where one seller stands with the marketplace, one row per currency:
          # earned, paid, still owed, and earnings the provider has not yet
          # confirmed.
          #
          # Under `payouts` rather than `sellers`: it is the ledger read from
          # the seller's side, and a finance operator reads it without holding
          # the key that edits sellers.
          class BalancesController < Admin::BaseController
            scoped_resource :payouts

            before_action :set_seller

            # GET /api/v3/admin/sellers/:seller_id/balances
            def index
              render json: { data: @seller.balances.map { |balance| serialize_balance(balance) } }
            end

            protected

            def read_actions
              %w[index]
            end

            private

            def set_seller
              @seller = current_store.sellers.find_by_prefix_id!(params[:seller_id])
              authorize! :index, Spree::SellerTransfer
            end

            def serialize_balance(balance)
              Spree.api.admin_seller_balance_serializer.new(balance, params: { store: current_store }).to_h
            end
          end
        end
      end
    end
  end
end
