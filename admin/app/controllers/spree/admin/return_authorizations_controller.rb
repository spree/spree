module Spree
  module Admin
    class ReturnAuthorizationsController < ResourceController
      add_breadcrumb_icon 'receipt-refund'
      add_breadcrumb Spree.t(:returns), :admin_customer_returns_path

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
    end
  end
end
