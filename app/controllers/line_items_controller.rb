class LineItemsController < Spree::BaseController

  def destroy
    line_item = LineItem.find(params[:id], :include => :order)
    order = line_item.order
    line_item.destroy
    order.update_totals!
    redirect_to edit_order_url(order.number)
  end

end
