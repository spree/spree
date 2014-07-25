module Spree
  module Admin
    class CustomerReturnsController < Spree::Admin::BaseController
      before_filter :load_order
      before_filter :load_return_items, only: [:new, :edit, :create]
      before_filter :load_editable_setting, only: [:new, :edit, :create]

      def index
        order_return_items = Spree::ReturnItem.accessible_by(current_ability, :read).where(inventory_unit_id: @order.inventory_units.pluck(:id))
        order_customer_returns = order_return_items.map(&:customer_return).compact.uniq
        @customer_returns = Kaminari.paginate_array(order_customer_returns).page(params[:page]).per(params[:per_page] || Spree::Config[:customer_returns_per_page])
      end

      def new
        @customer_return = Spree::CustomerReturn.new
      end

      def show
        @customer_return = Spree::CustomerReturn.accessible_by(current_ability, :read).find(params[:id])
        @pending_return_items = @customer_return.return_items.pending
        @accepted_return_items = @customer_return.return_items.accepted
        @rejected_return_items = @customer_return.return_items.rejected
        @manual_intervention_return_items = @customer_return.return_items.manual_intervention_required
      end

      def create
        @customer_return = Spree::CustomerReturn.new(stock_location_id: customer_return_params[:stock_location_id])
        @customer_return.return_items = build_return_items_from_params

        if @customer_return.save
          flash[:success] = flash_message_for(@customer_return, :successfully_created)
          redirect_to admin_order_customer_return_path(@order, @customer_return)
        else
          flash[:error] = Spree.t(:could_not_create_customer_return)
          render action: "new"
        end

      end

      private

        def load_order
          @order = Spree::Order.accessible_by(current_ability, :read).find_by(number: params[:order_id])
        end

        def load_return_items
          return_items_by_rma_id = @order.inventory_units.map(&:current_or_new_return_item).group_by(&:return_authorization_id)
          @new_return_items = filter_return_items_with_customer_returns(return_items_by_rma_id.delete(nil))
          @rma_return_items = filter_return_items_with_customer_returns(return_items_by_rma_id.values.flatten)
        end

        def load_editable_setting
          @allow_amount_edit = can?(:manage, Spree::CustomerReturn)
        end

        def customer_return_params
          params.require('customer_return').permit(permitted_customer_return_attributes)
        end

        def filter_return_items_with_customer_returns(return_items)
          return [] unless return_items
          return_items.select { |return_item| return_item.customer_return.nil? }
        end

        def build_return_items_from_params
          return_items_params = customer_return_params[:return_items_attributes].values

          return_items_params.map do |item_params|
            next unless item_params.delete('returned') == '1'
            return_item = Spree::ReturnItem.find_or_initialize_by(id: item_params[:id])
            return_item.assign_attributes(item_params)
            return_item
          end.compact
        end

    end
  end
end
