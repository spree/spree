module Spree
  module Api
    module V1
      class ReturnAuthorizationsController < Spree::Api::V1::BaseController

        def index
          authorize! :read, order
          @return_authorizations = order.return_authorizations
        end

        def show
          authorize! :read, order
          @return_authorization = order.return_authorizations.find(params[:id])
        end

        def create
          authorize! :read, order
          @return_authorization = order.return_authorizations.build(params[:return_authorization], :as => :api)
          if @return_authorization.save
            render :show, :status => 201
          else
            invalid_resource!(@return_authorization)
          end
        end

        def update
          authorize! :read, order
          @return_authorization = order.return_authorizations.find(params[:id])
          if @return_authorization.update_attributes(params[:return_authorization])
            render :show
          else
            invalid_resource!(@return_authorization)
          end
        end

        def destroy
          authorize! :read, order
          @return_authorization = order.return_authorizations.find(params[:id])
          @return_authorization.destroy
          render :text => nil, :status => 204
        end

        private

        def order
          @order ||= Order.find_by_number!(params[:order_id])
        end
      end
    end
  end
end
