module Spree
  module Api
    module V3
      module Seller
        # Where this seller stands: what they have earned, what has reached
        # them, and what the marketplace still owes — one row per currency.
        #
        # A computed collection rather than a resource: nothing here is a
        # record, so there is no id to fetch and nothing to page.
        class BalancesController < Seller::BaseController
          scoped_resource :seller_earnings

          # GET /api/v3/seller/balances
          def index
            authorize! :index, :seller_earnings

            render json: { data: current_seller.balances.map { |balance| serialize_balance(balance) } }
          end

          protected

          def read_actions
            %w[index]
          end

          private

          def serialize_balance(balance)
            Spree.api.seller_balance_serializer.new(balance, params: { store: current_store }).to_h
          end
        end
      end
    end
  end
end
