module Spree
  module Api
    module V1
      class ReturnAuthorizationsController < Spree::Api::BaseController
        before_filter :authorize_admin!

        def index
          @return_authorizations = order.return_authorizations.ransack(params[:q]).result
            .page(params[:page]).per(params[:per_page])
        end

        def show
          @return_authorization = order.return_authorizations.find(params[:id])
        end

        def create
          @return_authorization = order.return_authorizations.build(params[:return_authorization], :as => :api)
          if @return_authorization.save
            render :show, :status => 201
          else
            invalid_resource!(@return_authorization)
          end
        end

        def update
          @return_authorization = order.return_authorizations.find(params[:id])
          if @return_authorization.update_attributes(params[:return_authorization])
            render :show
          else
            invalid_resource!(@return_authorization)
          end
        end

        def destroy
          @return_authorization = order.return_authorizations.find(params[:id])
          @return_authorization.destroy
          render :text => nil, :status => 204
        end

        private

        def order
          @order ||= Order.find_by_number!(params[:order_id])
        end

        def authorize_admin!
          authorize! :manage, Spree::ReturnAuthorization
        end
      end
    end
  end
end
