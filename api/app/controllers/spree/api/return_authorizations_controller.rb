module Spree
  module Api
    class ReturnAuthorizationsController < Spree::Api::BaseController

      def create
        authorize! :create, ReturnAuthorization
        @return_authorization = order.return_authorizations.build(return_authorization_params)
        if @return_authorization.save
          render json: @return_authorization, status: 201
        else
          invalid_resource!(@return_authorization)
        end
      end

      def destroy
        @return_authorization = order.return_authorizations.accessible_by(current_ability, :destroy).find(params[:id])
        @return_authorization.destroy
        render nothing: true, status: 204
      end

      def index
        authorize! :admin, ReturnAuthorization
        @return_authorizations = order.return_authorizations.accessible_by(current_ability, :read).
                                 ransack(params[:q]).result.
                                 page(params[:page]).per(params[:per_page])
        render json: @return_authorizations, meta: pagination(@return_authorizations)
      end

      def new
        authorize! :admin, ReturnAuthorization
      end

      def show
        authorize! :admin, ReturnAuthorization
        @return_authorization = order.return_authorizations.accessible_by(current_ability, :read).find(params[:id])
        render json: @return_authorization
      end

      def update
        @return_authorization = order.return_authorizations.accessible_by(current_ability, :update).find(params[:id])
        if @return_authorization.update_attributes(return_authorization_params)
          render json: @return_authorization
        else
          invalid_resource!(@return_authorization)
        end
      end

      def cancel
        @return_authorization = order.return_authorizations.accessible_by(current_ability, :update).find(params[:id])
        if @return_authorization.cancel
          render json: @return_authorization
        else
          invalid_resource!(@return_authorization)
        end
      end

      private

      def order
        @order ||= Spree::Order.find_by!(number: order_id)
        authorize! :read, @order
      end

      def return_authorization_params
        params.require(:return_authorization).permit(permitted_return_authorization_attributes)
      end
    end
  end
end
