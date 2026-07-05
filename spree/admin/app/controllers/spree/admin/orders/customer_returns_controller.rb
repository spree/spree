module Spree
  module Admin
    module Orders
      class CustomerReturnsController < ResourceController
        include Spree::Admin::OrderConcern

        before_action :load_order
        before_action :load_form_data, only: [:new, :edit]

        create.before :build_return_items_from_params
        create.fails  :load_form_data

        def edit
          returned_items = @customer_return.return_items
          @pending_return_items = returned_items.select(&:pending?)
          @accepted_return_items = returned_items.select(&:accepted?)
          @rejected_return_items = returned_items.select(&:rejected?)
          @manual_intervention_return_items = returned_items.select(&:manual_intervention_required?)
          @pending_reimbursements = @customer_return.reimbursements.select(&:pending?)

          super
        end

        private

        def location_after_save
          spree.edit_admin_order_path(@order)
        end

        def build_resource
          current_store.customer_returns.new
        end

        def find_resource
          current_store.customer_returns.accessible_by(current_ability, :show).find_by_prefix_id!(params[:id])
        end

        def load_form_data
          return_items = @order.inventory_units.map(&:current_or_new_return_item).reject(&:customer_return_id)
          @rma_return_items = return_items.select(&:return_authorization_id)
        end

        def permitted_resource_params
          @permitted_resource_params ||= params.require(:customer_return).permit(permitted_customer_return_attributes)
        end

        def build_return_items_from_params
          return_items_params = permitted_resource_params.delete(:return_items_attributes).values

          @customer_return.return_items = return_items_params.map do |item_params|
            next unless item_params.delete('returned') == '1'

            return_item = item_params[:id] ? Spree::ReturnItem.find(item_params[:id]) : Spree::ReturnItem.new
            return_item.attributes = item_params
            return_item
          end.compact
        end

        def object_name
          'customer_return'
        end

        def object_url(object = nil, options = {})
          target = object || @object

          spree.admin_order_customer_return_url(@order, target, options)
        end

        def edit_object_url(object, options = {})
          target = object || @object

          spree.edit_admin_order_customer_return_url(@order, target, options)
        end

        def model_class
          Spree::CustomerReturn
        end
      end
    end
  end
end
