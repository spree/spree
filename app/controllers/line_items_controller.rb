class LineItemsController < Admin::BaseController
  resource_controller
  belongs_to :order
end