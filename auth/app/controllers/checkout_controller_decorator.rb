CheckoutController.class_eval do
  before_filter :check_authorization

  private
  def check_authorization
    authorize!(:edit, current_order)
  end
end