module Spree
  module Admin
    class CustomerReturnsController < ResourceController
      belongs_to 'spree/order', find_by: :number

      before_action :parent # ensure order gets loaded to support our pseudo parent-child relationship
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
        url_for([:edit, :admin, @order, @customer_return])
      end

      def build_resource
        Spree::CustomerReturn.new
      end

      def find_resource
        Spree::CustomerReturn.accessible_by(current_ability, :read).find(params[:id])
      end

      def collection
        parent # trigger loading the order
        @collection ||= Spree::ReturnItem
          .accessible_by(current_ability, :read)
          .where(inventory_unit_id: @order.inventory_units.pluck(:id))
          .map(&:customer_return).uniq.compact
        @customer_returns = @collection
      end

      def load_form_data
        return_items = @order.inventory_units.map(&:current_or_new_return_item).reject(&:customer_return_id)
        @rma_return_items = return_items.select(&:return_authorization_id)
      end

      def permitted_resource_params
        @permitted_resource_params ||= params.require('customer_return').permit(permitted_customer_return_attributes)
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

    end
  end
end
