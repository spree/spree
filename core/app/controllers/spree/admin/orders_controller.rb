module Spree
  module Admin
    class OrdersController < BaseController
      require 'spree/core/gateway_error'
      before_filter :initialize_txn_partials
      before_filter :initialize_order_events
      before_filter :load_order, :only => [:show, :edit, :update, :fire, :resend, :history, :user]

      respond_to :html

      def index
        params[:search] ||= {}
        params[:search][:completed_at_is_not_null] ||= '1' if Spree::Config[:show_only_complete_orders_by_default]
        @show_only_completed = params[:search][:completed_at_is_not_null].present?
        params[:search][:meta_sort] ||= @show_only_completed ? 'completed_at.desc' : 'created_at.desc'

        @search = Order.metasearch(params[:search])

        if !params[:search][:created_at_greater_than].blank?
          params[:search][:created_at_greater_than] = Time.zone.parse(params[:search][:created_at_greater_than]).beginning_of_day rescue ""
        end

        if !params[:search][:created_at_less_than].blank?
          params[:search][:created_at_less_than] = Time.zone.parse(params[:search][:created_at_less_than]).end_of_day rescue ""
        end

        if @show_only_completed
          params[:search][:completed_at_greater_than] = params[:search].delete(:created_at_greater_than)
          params[:search][:completed_at_less_than] = params[:search].delete(:created_at_less_than)
        end

        @orders = Order.metasearch(params[:search]).includes([:user, :shipments, :payments]).page(params[:page]).per(Spree::Config[:orders_per_page])
        respond_with(@orders)
      end

      def show
        respond_with(@order)
      end

      def new
        @order = Order.create
        respond_with(@order)
      end

      def edit
        respond_with(@order)
      end

      def update
        return_path = nil
        if @order.update_attributes(params[:order]) && @order.line_items.present?
          unless @order.complete?
            if params[:order].key?(:email)
              shipping_method = @order.available_shipping_methods(:front_end).first
              if shipping_method
                @order.shipping_method = shipping_method

                if params[:guest_checkout] == 'false' && params[:user_id].present?
                  @order.user_id = params[:user_id]
                  @order.user true
                end
                @order.save
                @order.create_shipment!
                return_path = edit_admin_order_shipment_path(@order, @order.shipment)
              else
                flash[:error] = t('errors.messages.no_shipping_methods_available')
                return_path = user_admin_order_path(@order)
              end
            else
              return_path = user_admin_order_path(@order)
            end

          else
            return_path = admin_order_path(@order)
          end
        else
          @order.errors.add(:line_items, t('errors.messages.blank'))
        end

        respond_with(@order) do |format|
          format.html do
            if return_path
              redirect_to return_path
            else
              render :action => :edit
            end
          end
        end
      end


      def fire
        # TODO - possible security check here but right now any admin can before any transition (and the state machine
        # itself will make sure transitions are not applied in the wrong state)
        event = params[:e]
        if @order.send("#{event}")
          flash.notice = t(:order_updated)
        else
          flash[:error] = t(:cannot_perform_operation)
        end
      rescue Spree::Core::GatewayError => ge
        flash[:error] = "#{ge.message}"
      ensure
        respond_with(@order) { |format| format.html { redirect_to :back } }
      end

      def resend
        OrderMailer.confirm_email(@order, true).deliver
        flash.notice = t(:order_email_resent)

        respond_with(@order) { |format| format.html { redirect_to :back } }
      end

      def user
        @order.build_bill_address(:country_id => Spree::Config[:default_country_id]) if @order.bill_address.nil?
        @order.build_ship_address(:country_id => Spree::Config[:default_country_id]) if @order.ship_address.nil?
      end

      private

      def load_order
        @order ||= Order.find_by_number(params[:id], :include => :adjustments) if params[:id]
        @order
      end

      # Allows extensions to add new forms of payment to provide their own display of transactions
      def initialize_txn_partials
        @txn_partials = []
      end

      # Used for extensions which need to provide their own custom event links on the order details view.
      def initialize_order_events
        @order_events = %w{cancel resume}
      end

    end
  end
end
