module Spree
  module Admin
    class ReimbursementsController < ResourceController
      belongs_to 'spree/order', find_by: :number

      before_action :load_simulated_refunds, only: :edit
      before_action :assign_performer, only: :perform

      rescue_from Spree::Core::GatewayError, with: :spree_core_gateway_error

      def perform
        @reimbursement.perform!
        redirect_to location_after_save
      end

      private

      def build_resource
        if params[:build_from_customer_return_id].present?
          customer_return = current_store.customer_returns.find(params[:build_from_customer_return_id])

          Reimbursement.build_from_customer_return(customer_return)
        else
          super
        end
      end

      def location_after_save
        if @reimbursement.reimbursed?
          admin_order_reimbursement_path(parent, @reimbursement)
        else
          edit_admin_order_reimbursement_path(parent, @reimbursement)
        end
      end

      def load_simulated_refunds
        @reimbursement_objects = @reimbursement.simulate
      end

      def spree_core_gateway_error(error)
        flash[:error] = error.message
        redirect_to spree.edit_admin_order_reimbursement_path(parent, @reimbursement)
      end

      def assign_performer
        @reimbursement.update!(performed_by: try_spree_current_user)
      end
    end
  end
end
