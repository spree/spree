module Spree
  class OrderStatusController < StoreController
    # page for user to input their email address and order number
    # GET /order_status
    def new; end

    # validate email/order number and redirect to order page
    # POST /order_status
    def create
      raise ActiveRecord::RecordNotFound if params[:number].blank?

      @order = order_finder.new(number: params[:number], email: params[:email], store: current_store).execute.first

      if @order
        redirect_to spree.order_path(@order, token: @order.token), status: :see_other
      else
        flash[:error] = Spree.t(:order_not_found)
        render :new, status: :unprocessable_entity
      end
    end

    private

    def accurate_title
      Spree.t(:order_status)
    end

    def order_finder
      Spree::Dependencies.completed_order_finder.constantize
    end
  end
end
