module Spree
  module Admin
    module Orders
      class ReturnAuthorizationsController < ResourceController
        include Spree::Admin::OrderConcern
        include Spree::Admin::OrderBreadcrumbConcern

        before_action :load_order
        before_action :add_breadcrumb_for_order

        before_action :load_return_authorization
        before_action :load_form_data, only: [:new, :edit]
        before_action :load_refunds, only: :show
        create.fails  :load_form_data
        update.fails  :load_form_data

        private


        def add_breadcrumb_for_order
          add_breadcrumb @order.number, spree.edit_admin_order_path(@order)
        end

        def location_after_save
          spree.edit_admin_order_path(@order)
        end

        def load_form_data
          load_return_items
          load_reimbursement_types
          load_return_authorization_reasons
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

        def load_return_authorization
          if @object.order.nil?
            @object.order = @order
          end

          @return_authorization = @object
        end

        def object_name
          'return_authorization'
        end

        def object_url(object = nil, options = {})
          target = object || @object

          spree.admin_order_return_authorization_url(@order, target, options)
        end

        def edit_object_url(object, options = {})
          target = object || @object

          spree.edit_admin_order_return_authorization_url(@order, target, options)
        end

        def model_class
          Spree::ReturnAuthorization
        end

        def permitted_resource_params
          params.require(:return_authorization).permit(permitted_return_authorization_attributes)
        end
      end
    end
  end
end
