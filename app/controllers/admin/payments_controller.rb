class Admin::PaymentsController < Admin::BaseController
  resource_controller
  belongs_to :order
  ssl_required
end
