module Spree
  module Admin
    class ReimbursementsController < ResourceController
      belongs_to 'spree/order', find_by: :number

      before_filter :load_return_item_ids, only: :create
      before_filter :load_simulated_refunds, only: :edit

      def perform
        @reimbursement.perform!
        redirect_to url_for([:admin, @order, @reimbursement.customer_return])
      end

      private

      def load_return_item_ids
        if params[:return_item_ids].present?
          params[:reimbursement] ||= ActiveSupport::HashWithIndifferentAccess.new
          params[:reimbursement][:return_item_ids] = params[:return_item_ids].split(',')
        end
      end

      def location_after_save
        edit_admin_order_reimbursement_path(@order, @reimbursement)
      end

      def load_simulated_refunds
        @reimbursement_items = @reimbursement.simulate
      end

    end
  end
end
