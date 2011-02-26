class Admin::AdjustmentsController < Admin::ResourceOrderController
  destroy.after :reload_order

  private
  
  def reload_order
    @order.reload
  end
end
