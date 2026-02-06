module Spree
  module Admin
    class OrdersController < Spree::Admin::ResourceController
      include Spree::Admin::OrderConcern
      include Spree::Admin::OrdersFiltersHelper
      include Spree::Admin::OrderBreadcrumbConcern
      include Spree::Admin::TableConcern

      before_action :initialize_order_events
      before_action :load_order, only: %i[show edit cancel resend destroy]
      before_action :load_order_items, only: :show
      before_action :load_user, only: [:index]

      # GET /admin/orders/new
      def new
        @order = current_store.orders.new
      end

      # POST /admin/orders
      def create
        @order = current_store.orders.new(permitted_resource_params)
        @order.created_by = try_spree_current_user
        if @order.save
          flash[:success] = flash_message_for(@order, :successfully_created)
          redirect_to spree.edit_admin_order_path(@order)
        else
          render :new, status: :unprocessable_entity
        end
      end

      # GET /admin/orders/:id
      def show
        unless @order.completed?
          add_breadcrumb Spree.t(:draft_orders), :admin_checkouts_path
        end

        add_breadcrumb @order.number, spree.admin_order_path(@order)
      end

      # GET /admin/orders/:id/edit
      def edit
        redirect_to spree.admin_order_path(@order)
      end

      # GET /admin/orders
      def index; end

      # PUT /admin/orders/:id/cancel
      def cancel
        @order.canceled_by(try_spree_current_user)
        flash[:success] = Spree.t(:order_canceled)
        redirect_back fallback_location: spree.edit_admin_order_url(@order)
      end

      # POST /admin/orders/:id/resend
      def resend
        if @order.completed?
          Spree::Events.publish('order.resend_confirmation_email', { 'id' => @order.id })
          flash[:success] = Spree.t(:order_email_resent)
        else
          flash[:error] = Spree.t(:order_email_resent_error)
        end

        redirect_back fallback_location: spree.edit_admin_order_url(@order)
      end

      # DELETE /admin/orders/:id
      def destroy
        @order.destroy
        flash[:success] = flash_message_for(@order, :successfully_removed)

        if @order.completed?
          redirect_to spree.admin_orders_path
        else
          redirect_to spree.admin_checkouts_path
        end
      end

      private

      def scope
        base_scope = current_store.orders.accessible_by(current_ability, :index)

        if action_name == 'index'
          base_scope.complete
        else
          base_scope
        end.includes(collection_includes)
      end

      def collection_default_sort
        'completed_at desc'
      end

      def collection_includes
        { user: [], payments: [], refunds: [], shipments: :stock_location }
      end

      def order_params
        params[:created_by_id] = try_spree_current_user.try(:id)
        params.permit(:created_by_id, :user_id, :store_id, :channel, tag_list: [])
      end

      def load_order
        @order = scope.includes(:adjustments).find_by_prefix_id!(params[:id])
        authorize! action, @order
      end

      # Used for extensions which need to provide their own custom event links on the order details view.
      def initialize_order_events
        @order_events = %w{approve cancel resume}
      end

      def model_class
        Spree::Order
      end

      # needed to show the delete button in the content header
      def object_url
        spree.admin_order_path(@order)
      end

      def permitted_resource_params
        params.require(:order).permit(permitted_order_attributes)
      end

      def update_turbo_stream_enabled?
        true
      end
    end
  end
end
