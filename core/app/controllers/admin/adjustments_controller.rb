class Admin::AdjustmentsController < Admin::BaseController
  resource_controller
  belongs_to :order
  ssl_required

  update.wants.html { redirect_to collection_url }
  create.wants.html { redirect_to collection_url }
  destroy.success.wants.js { render_js_for_destroy }

  # TODO: refactor into Order class
  # Automatically complete and order where no payment is necessary because adjustments cancel out the total
  # def set_order_state
  #   @order.update_totals!

  #   if @order.in_progress? and @order.item_total > 0 and @order.total == 0 and @order.payments.total == 0  #for new orders that are adjusted to zero
  #     until @order.checkout.complete?
  #       @order.checkout.next!
  #     end
  #     @order.reload.pay!
  #   elsif @order.item_total > 0 && ((@order.balance_due? && @order.outstanding_balance == 0) || (@order.credit_owed? && @order.outstanding_credit == 0)) #set existing orders back to paid, if adjustment corrects balance
  #     @order.reload.pay!
  #   end
  # end

end
