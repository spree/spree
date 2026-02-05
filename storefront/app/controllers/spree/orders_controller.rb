# overwrote this controller to drop empty and show actions
# show action has it's own controller order_status
# empty is not needed anymore
module Spree
  class OrdersController < StoreController
    include Spree::Core::ControllerHelpers::Order
    include CartMethods

    helper 'spree/products'

    before_action :assign_order_with_lock, only: :update

    rescue_from CanCan::AccessDenied do |exception|
      raise ActiveRecord::RecordNotFound
    end

    # GET /orders/:id
    def show
      @order = complete_order_finder.new(number: params[:id], token: params[:token], store: current_store).execute.first

      raise ActiveRecord::RecordNotFound if @order.blank?

      authorize! :show, @order, params[:token]

      @shipments = @order.shipments.includes(:stock_location, :address, selected_shipping_rate: :shipping_method, inventory_units: :line_item)
    end

    # PUT /cart
    def update
      @variant = current_store.variants.find(params[:variant_id]) if params[:variant_id]
      @result = cart_update_service.call(order: @order, params: order_params)

      if @result.success?
        if params.key?(:checkout)
          @order.next if @order.cart?
          redirect_to spree.checkout_state_path(@order.token, @order.checkout_steps.first)
        else
          redirect_to spree.cart_path
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # GET /cart
    def edit
      flash.keep if request.format.turbo_stream?
      @order = current_order || find_order_by_cookie
      associate_user

      remove_out_of_stock_items
      load_line_items
    end

    private

    def authorize_access
      authorize! :show, @order, params[:token]
    end

    def find_order_by_cookie
      if order_token.present?
        current_store.orders.incomplete.not_canceled.
          includes(line_items: [variant: [:images, :product, { option_values: :option_type }]]).
          find_by(token: order_token)
      else
        current_store.orders.incomplete.new
      end
    end

    def accurate_title
      if ['edit', 'update'].include?(action_name)
        Spree.t(:shopping_cart)
      else
        Spree.t(:order_number, number: @order&.number)
      end
    end

    def order_params
      if params[:order]
        params[:order].permit(*permitted_order_attributes)
      else
        {}
      end
    end

    def cart_remove_out_of_stock_items_service
      Spree::Dependencies.cart_remove_out_of_stock_items_service.constantize
    end

    def cart_update_service
      Spree::Dependencies.cart_update_service.constantize
    end

    def complete_order_finder
      Spree::Dependencies.completed_order_finder.constantize
    end

    def remove_out_of_stock_items
      return unless @order&.persisted?

      ActiveRecord::Base.connected_to(role: :writing) do
        @order, messages = cart_remove_out_of_stock_items_service.call(order: @order).value
        flash[:error] = messages.to_sentence if messages.any?
      end
    end
  end
end
