class Admin::ShipmentsController < Admin::BaseController
  resource_controller
  belongs_to :order
  
  update.response do |wants|
    wants.html do 
      redirect_to admin_order_url(@order)
    end
  end
  
end