class Admin::CreditcardPaymentsController < Admin::BaseController
  resource_controller
  belongs_to :order
  ssl_required
end
