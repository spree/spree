CheckoutController.class_eval do
  before_filter :check_authorization
  before_filter :check_registration, :except => [:registration, :update_registration]

  def registration
    @user = User.new
  end

  def update_registration
    if current_order.update_attributes(params[:order])
      redirect_to checkout_path
    else
      render 'registration'
    end
  end

  private
  def check_authorization
    authorize!(:edit, current_order)
  end

  # Introduces a registration step whenever the +registration_step+ preference is true.
  def check_registration
    return unless Spree::Auth::Config[:registration_step]
    return if Spree::Config[:allow_guest_checkout] and current_order.email.present?
    return if current_user or not current_order.user.anonymous?
    redirect_to checkout_registration_path
  end

end
