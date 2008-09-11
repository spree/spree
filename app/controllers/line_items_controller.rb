class LineItemsController < Admin::BaseController
  layout 'application'
  
  resource_controller
  belongs_to :order
end