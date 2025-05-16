module Spree
  module Admin
    class ReturnAuthorizationsController < ResourceController
      def index; end

      def cancel
        @return_authorization.cancel!
        flash[:success] = Spree.t(:return_authorization_canceled)
        redirect_back fallback_location: spree.edit_admin_order_path(@return_authorization.order)
      end

      private

      def permitted_resource_params
        params.require(:return_authorization).permit(permitted_return_authorization_attributes)
      end

      def location_after_destroy
        spree.edit_admin_order_path(@return_authorization.order)
      end

      def collection
        return @collection if @collection.present?

        params[:q] ||= {}

        # @search needs to be defined as this is passed to search_form_for
        @search = current_store.return_authorizations.accessible_by(current_ability, :index).ransack(params[:q])
        @collection = @search.result.order(created_at: :desc).page(params[:page]).per(params[:per_page])
      end
    end
  end
end
