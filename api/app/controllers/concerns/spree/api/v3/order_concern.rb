module Spree
  module Api
    module V3
      module OrderConcern
        extend ActiveSupport::Concern

        # Allow access to order via order token for guests or authenticated users
        # Expects @parent to be set to the order
        def authorize_order_access!
          authorize!(:update, @parent, order_token)
        end

        protected

        def order_token
          # Check X-Spree-Order-Token header first
          header = request.headers['X-Spree-Order-Token']
          return header if header.present?

          # Fallback to query param
          params[:token]
        end
      end
    end
  end
end
