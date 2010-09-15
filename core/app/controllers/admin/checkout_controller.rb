class Admin::CheckoutController  < Admin::BaseController

  helper :checkout
  before_filter :load_data

  def update
    if @order.update_attributes(params[:order])
      if @order.completed?
        redirect_to admin_checkout_url(@order)
      else
        redirect_to edit_admin_order_shipment_url(@order, @order.shipment)
      end
    else
      render :edit
    end
  end

  private
  def load_data
    @order = Order.find_by_number(params[:number])
  end

end
