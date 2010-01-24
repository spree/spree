class Admin::CreditcardsController < Admin::BaseController
  resource_controller
  belongs_to :order
  
  # temporary, creditcards should be assigned to order
  def collection
    [@order.checkout.creditcard]
  end
  
end
