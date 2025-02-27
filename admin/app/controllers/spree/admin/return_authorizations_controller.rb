module Spree
  module Admin
    class ReturnAuthorizationsController < ResourceController
      belongs_to 'spree/order', find_by: :number

      before_action :load_form_data, only: [:new, :edit]
      before_action :load_refunds, only: :show
      create.fails  :load_form_data
      update.fails  :load_form_data

      def cancel
        @return_authorization.cancel!
        flash[:success] = Spree.t(:return_authorization_canceled)
        redirect_back fallback_location: spree.edit_admin_order_path(@order)
      end

      private

      def load_form_data
        load_return_items
        load_reimbursement_types
        load_return_authorization_reasons
      end

      def location_after_destroy
        spree.edit_admin_order_path(@order)
      end

      # To satisfy how nested attributes works we want to create placeholder ReturnItems for
      # any InventoryUnits that have not already been added to the ReturnAuthorization.
      def load_return_items
        all_inventory_units = @return_authorization.order.inventory_units
        associated_inventory_units = @return_authorization.return_items.map(&:inventory_unit)
        unassociated_inventory_units = all_inventory_units - associated_inventory_units

        new_return_items = unassociated_inventory_units.map do |new_unit|
          Spree::ReturnItem.new(inventory_unit: new_unit, return_authorization: @return_authorization).tap(&:set_default_pre_tax_amount)
        end

        @form_return_items = (@return_authorization.return_items + new_return_items).sort_by(&:inventory_unit_id)
      end

      def load_reimbursement_types
        @reimbursement_types = Spree::ReimbursementType.accessible_by(current_ability).active
      end

      def load_return_authorization_reasons
        @reasons = Spree::ReturnAuthorizationReason.active.to_a
        # Only allow an inactive reason if it's already associated to the RMA
        if @return_authorization.reason && !@return_authorization.reason.active?
          @reasons << @return_authorization.reason
        end
      end

      def load_refunds
        reimbursements = @return_authorization.reimbursements
        refunds = @return_authorization.refunds

        @refunds = refunds.any? ? refunds : reimbursements.flat_map(&:simulate)
      end
    end
  end
end
