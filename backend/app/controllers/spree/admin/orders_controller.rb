module Spree
  module Admin
    class OrdersController < Spree::Admin::BaseController
      before_action :initialize_order_events
      before_action :load_order, only: [:edit, :update, :cancel, :resume, :approve, :resend, :open_adjustments, :close_adjustments, :cart]

      respond_to :html

      def index
        params[:q] ||= {}
        params[:q][:completed_at_not_null] ||= '1' if Spree::Config[:show_only_complete_orders_by_default]
        @show_only_completed = params[:q][:completed_at_not_null] == '1'
        params[:q][:s] ||= @show_only_completed ? 'completed_at desc' : 'created_at desc'
        params[:q][:completed_at_not_null] = '' unless @show_only_completed

        # As date params are deleted if @show_only_completed, store
        # the original date so we can restore them into the params
        # after the search
        created_at_gt = params[:q][:created_at_gt]
        created_at_lt = params[:q][:created_at_lt]

        params[:q].delete(:inventory_units_shipment_id_null) if params[:q][:inventory_units_shipment_id_null] == "0"

        if params[:q][:created_at_gt].present?
          params[:q][:created_at_gt] = Time.zone.parse(params[:q][:created_at_gt]).beginning_of_day rescue ""
        end

        if params[:q][:created_at_lt].present?
          params[:q][:created_at_lt] = Time.zone.parse(params[:q][:created_at_lt]).end_of_day rescue ""
        end

        if @show_only_completed
          params[:q][:completed_at_gt] = params[:q].delete(:created_at_gt)
          params[:q][:completed_at_lt] = params[:q].delete(:created_at_lt)
        end

        @search = Order.accessible_by(current_ability, :index).ransack(params[:q])

        # lazyoading other models here (via includes) may result in an invalid query
        # e.g. SELECT  DISTINCT DISTINCT "spree_orders".id, "spree_orders"."created_at" AS alias_0 FROM "spree_orders"
        # see https://github.com/spree/spree/pull/3919
        @orders = @search.result(distinct: true).
          page(params[:page]).
          per(params[:per_page] || Spree::Config[:orders_per_page])

        # Restore dates
        params[:q][:created_at_gt] = created_at_gt
        params[:q][:created_at_lt] = created_at_lt
      end

      def new
        @order = Order.create(order_params)
        redirect_to cart_admin_order_url(@order)
      end

      def edit
        can_not_transition_without_customer_info

        unless @order.completed?
          @order.refresh_shipment_rates(ShippingMethod::DISPLAY_ON_FRONT_AND_BACK_END)
        end
      end

      def cart
        unless @order.completed?
          @order.refresh_shipment_rates
        end
        if @order.shipments.shipped.count > 0
          redirect_to edit_admin_order_url(@order)
        end
      end

      def update
        if @order.update_attributes(params[:order]) && @order.line_items.present?
          @order.update!
          unless @order.completed?
            # Jump to next step if order is not completed.
            redirect_to admin_order_customer_path(@order) and return
          end
        else
          @order.errors.add(:line_items, Spree.t('errors.messages.blank')) if @order.line_items.empty?
        end

        render :action => :edit
      end

      def cancel
        @order.canceled_by(try_spree_current_user)
        flash[:success] = Spree.t(:order_canceled)
        redirect_to :back
      end

      def resume
        @order.resume!
        flash[:success] = Spree.t(:order_resumed)
        redirect_to :back
      end

      def approve
        @order.approved_by(try_spree_current_user)
        flash[:success] = Spree.t(:order_approved)
        redirect_to :back
      end

      def resend
        OrderMailer.confirm_email(@order.id, true).deliver_later
        flash[:success] = Spree.t(:order_email_resent)

        redirect_to :back
      end

      def open_adjustments
        adjustments = @order.all_adjustments.where(state: 'closed')
        adjustments.update_all(state: 'open')
        flash[:success] = Spree.t(:all_adjustments_opened)

        respond_with(@order) { |format| format.html { redirect_to :back } }
      end

      def close_adjustments
        adjustments = @order.all_adjustments.where(state: 'open')
        adjustments.update_all(state: 'closed')
        flash[:success] = Spree.t(:all_adjustments_closed)

        respond_with(@order) { |format| format.html { redirect_to :back } }
      end

      private
        def order_params
          params[:created_by_id] = try_spree_current_user.try(:id)
          params.permit(:created_by_id, :user_id)
        end

        def load_order
          @order = Order.includes(:adjustments).friendly.find(params[:id])
          authorize! action, @order
        end

        # Used for extensions which need to provide their own custom event links on the order details view.
        def initialize_order_events
          @order_events = %w{approve cancel resume}
        end

        def model_class
          Spree::Order
        end
    end
  end
end
