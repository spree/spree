module Spree
  class OrderStatusController < StoreController
    # page for user to input their email address and order number
    # GET /order_status
    def new; end

    # validate email/order number and redirect to order page
    # POST /order_status
    def create
      @order = current_store.orders.complete.without_vendor.find_by(number: params[:number], email: params[:email])

      if @order
        redirect_to spree.order_path(@order, token: @order.token)
      else
        flash[:error] = Spree.t(:order_not_found)
        render :new
      end
    end

    private

    def accurate_title
      Spree.t(:order_status)
    end
  end
end
