module Spree
  module Api
    class ReturnAuthorizationsController < Spree::Api::BaseController
      respond_to :json

      before_filter :authorize_admin!

      def index
        @return_authorizations = order.return_authorizations.
                                 ransack(params[:q]).result.
                                 page(params[:page]).per(params[:per_page])
        respond_with(@return_authorizations)
      end

      def show
        @return_authorization = order.return_authorizations.find(params[:id])
        respond_with(@return_authorization)
      end

      def create
        @return_authorization = order.return_authorizations.build(params[:return_authorization], :as => :api)
        if @return_authorization.save
          respond_with(@return_authorization, :status => 201, :default_template => :show)
        else
          invalid_resource!(@return_authorization)
        end
      end

      def update
        @return_authorization = order.return_authorizations.find(params[:id])
        if @return_authorization.update_attributes(params[:return_authorization])
          respond_with(@return_authorization, :default_template => :show)
        else
          invalid_resource!(@return_authorization)
        end
      end

      def destroy
        @return_authorization = order.return_authorizations.find(params[:id])
        @return_authorization.destroy
        respond_with(@return_authorization, :status => 204)
      end

      def add
        @return_authorization = order.return_authorizations.accessible_by(current_ability, :update).find(params[:id])
        @return_authorization.add_variant params[:variant_id].to_i, params[:quantity].to_i
        if @return_authorization.valid?
          respond_with @return_authorization, default_template: :show
        else
          invalid_resource!(@return_authorization)
        end
      end

      def receive
        @return_authorization = order.return_authorizations.accessible_by(current_ability, :update).find(params[:id])
        if @return_authorization.receive
          respond_with @return_authorization, default_template: :show
        else
          invalid_resource!(@return_authorization)
        end
      end

      def cancel
        @return_authorization = order.return_authorizations.accessible_by(current_ability, :update).find(params[:id])
        if @return_authorization.cancel
          respond_with @return_authorization, default_template: :show
        else
          invalid_resource!(@return_authorization)
        end
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
