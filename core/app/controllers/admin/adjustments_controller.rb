class Admin::AdjustmentsController < Admin::BaseController
  resource_controller
  belongs_to :order

  update.wants.html { redirect_to collection_url }
  create.wants.html { redirect_to collection_url }
  destroy.success.wants.js { @order.reload && render_js_for_destroy }

end
